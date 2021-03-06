Getting started tutorial using Jerakia and Puppet
==============================

# About #

This is a *very quick*start guide for users already familiar with Puppet and Hiera who want to dive right in....

Note - the following is tested against Puppet 3.x, testing on Puppet 4 is ongoing

# Installation #

Jerakia is installed from a rubygem, simply;

`gem install jerakia`

# Configuration #

## Jerakia configuration file ##

The first step is to create a basic configuration file for Jerakia to tell it where to load policies, log data...etc

    # mkdir /etc/jerakia
    # vim /etc/jerakia/jerakia.yaml

A basic configuration looks like:

    ---
    policydir: /etc/jerakia/policy.d
    logfile: /var/log/jerakia.log
    loglevel: info

If you are going to use the encryption output filter provided by hiera-eyaml to enable you to use encrypted strings in your data, you can provide the keys here

    eyaml:
      private_key: /path/to/my/privkey.pem
      public_key: /path/to/my/publickey.pem

# Create your default policy #

## The policy file ##

All jerakia requests are processed using a lookup policy.  Policy filenames should correspond to the name of the policy and are loaded from the `policydir` directive in jerakia.yaml.  If you don't specify a policy name in the lookup request then the name _default_ is used.  So let's create that now.

    # mkdir /etc/jerakia/policy.d
    # vim /etc/jerakia/policy.d/default.rb

Jerakia policies are written in ruby DSL, therefore you a free to use any ruby you wish.  A Jerakia policy is defined as a block.

    policy :default do
    
    end

## Lookups ##

Jerakia policies are containers for lookups, which are performed in order.  A lookup contains a data source that should be used for the data lookup along with any plugun functions.  A simple example using the file data source to source data from yaml files would look like;

    policy :default do

      lookup :default do
        datasource :file, {
          :format     => :yaml,
          :docroot    => "/var/lib/jerakia",
          :searchpath => [
            "hostname/#{scope[:fqdn]}",
            "environment/#{scope[:environment]}",
            "common",
           ],
        }
      end

    end
 


# Add data to Jerakia #

## Data files ##

Using the YAML [file datasource](datasources/file.md), we'll now add some configuraton data for Jerakia to query,  first lets create the directory structure

    # cd /var/lib/jerakia
    # mkdir -p common hostname/fake.server.com environment/development

Jerakia lookups contain two important components, a _namespace_ and a _key_, by default the file backend will search for your key in a file corresponding to `<path>/<namespace>.yaml`.  So let's create that now for a fictional _servers_ key in the _ntp_ namespace

    # vim /var/lib/jerakia/common/ntp.yaml

In this document we put our configuration for the _ntp_ namespace

    ---
    servers:
      - ntp0.fake.com
      - ntp1.fake.com

## Query Jerakia from the command line ##

Using the key and the namespace we can now query this data directly from Jerakia

    # jerakia -k servers -n ntp
    ["ntp0.fake.com","ntp1.fake.com"]

## Hierarical overrides ##

Note the hierarchy that we have defined in our lookups. The scope is a bunch of key/value metadata that is sent with the request.  In Puppet terms, these would be facts and top-level variables.  In our fictional environment we are going to override the ntp servers for everything in the dev environment by creating a new data file at the environment level.

    # mkdir /var/lib/jerakia/environment/development
    # vim /var/lib/jerakia/environment/development/ntp.yaml

And put in different server names 

    ---
    servers:
      - ntp0.devbox.com
      - ntp1.devbox.com

## Query using scope ##

We can simulate the scope of the lookup request on the command line by passing key:val pairs after the arguments

    # jerakia -k servers -n ntp environment:production
    ["ntp0.fake.com","ntp1.fake.com"]
    
By running against production, we have the values returned from common as there is no production environment defined, but if we now run the same lookup but with development environment in the scope, we get different results

    # jerakia -k servers -n ntp environment:development
    ["ntp0.devbox.com","ntp1.devbox.com"]

# Integration with Puppet #

There are a few options to integrate Jerakia with Puppet.


## As a hiera backend ##

Hiera can be enabled very simply by simply adding it as a backend to hiera

    # vim /etc/hiera.yaml

Jerakia can be used in place of, or addition to, other hiera backends.

    ---
    :backends:
      - jerakia

We can now query the same data using Hiera

    # hiera ntp::servers environment=production
    ["ntp0.fake.com","ntp1.fake.com"]
     
    # hiera ntp::servers environment=development
    ["ntp0.devbox.com","ntp1.devbox.com"]

Note that using the Hiera backend, a query of foo::bar will send a lookup request to Jerakia for the key _bar_ with the namespace _foo_

## The Puppet data binding terminus ##

Jerakia supports a puppet data binding terminus for direct integration, this is the preferred method of using Jerakia from Puppet although we still advise having the hiera backend to support any modules that use hiera() function calls directly.  Using the data binding terminus however will route all data mapping requests from parametersed classes directly to Jerakia.

This can be configured in `/etc/puppet/puppet.conf` under the `[master]` section

      [master]
        data_terminus = jerakia

Let's write a small module to test this....

    # mkdir -p /etc/puppet/modules/ntp/manifests
    # vim /etc/puppet/modules/ntp/manifests/init.pp

A simple class to perform a data mapping lookup.

    class ntp (
      $servers = 'unknown',
    ) {
      notify { $servers: }
    }

Now we should be able to use Jerakia transparently from Puppet

    # puppet -e 'include ntp'
    Notice: /Stage[main]/Ntp/Notify[ntp0.fake.com]/message: defined 'message' as 'ntp0.fake.com'
    Notice: /Stage[main]/Ntp/Notify[ntp1.fake.com]/message: defined 'message' as 'ntp1.fake.com'


# Existing Hiera compatibility #

You would have noted by now that Jerakia does things slightly differently from Hiera, notably the location of files using the namespace as the filename.  Whereas Jerakia searches for _key_ in `<path>/<namespace>.yaml`  Hiera will search for `<namespace>::<key>` in `<path>.yaml`  (note the file extentions).  It is however possible to use Jerakia on top of your existing Hiera file structure in order to test drive it without modifying your data by using the hiera_compat plugin that ships with Jerakia.

An example Hiera herarchy would like:

    # cat /var/lib/hiera/common.yaml
    ---
    apache::port: 80
    ntp::servers:
      - ntp0.fake.com
      - ntp1.fake.com
 
The corresponding hiera.yaml file might contain

    ---
    :backends:
      - yaml

    :yaml:
      :datadir: /var/lib/hiera

    :hierarchy:
      - "hostname/%{hostname}"
      - "environment/%{environment}"
      - "common"

Using the hiera_compat plugin, the jerakia lookup is rewritten to mesh the lookup key to _<namespace>::<key>_ and drop the namespace from the request, meaning Jerakia will search for _<namespace>::<key>_ in _<path>.yaml, just like Hiera.   Here is an example of a Jerakia policy that simulates the same Hiera config

    policy :default do

      lookup :default, :use => :hiera do
        datasource :file, {
          :format     => :yaml,
          :extension  => 'yaml', # Remember what we said about extensions?
          :searchpath => [
            "hostname/#{scope[:hostname]}",
            "environment/#{scope[:environment]}",
            "common",
          ],
        }
        plugin.hiera.rewrite_request
      end
    end


# Further reading #

Some other examples of Jerakia policies and lookups with various plugins [can be found here](policy.md) with further documentation appearing in the docs/ section of the site.

We are trying to document this as fast as we write it - please bear with us.
