# cocoapods-cordova

Cocoapods plugin for developing Cordova plugins

**Requires Cocoapods >= 0.34.0**

## Features

* Facilitates the use of Cocoapods packages in Cordova plugins
* Allows plugin testing within Xcode
* Builds plugin as a static library for use in Cordova apps
* Manages `plugin.xml` sources, libraries, frameworks, resources and
  headers automatically
* Intelligently links dependencies to prevent duplicate symbols in Cordova apps

## Installation

Add `cocoapods` and `cocoapods-cordova` to your `Gemfile`:

```ruby
gem 'cocoapods', '~> 0.34.0'
gem 'cocoapods-cordova', :github => 'xdissent/cocoapods-cordova'
```

Update the bundle:

```console
$ bundle install
```

## Usage

To build a plugin and update `plugin.xml`:

```console
$ bundle exec pod cordova
```

## Step-by-step Cordova plugin tutorial

* Create a new Xcode project using the "Cocoa Touch Static Library" template.

* Add `Gemfile`:

```ruby
source 'https://rubygems.org'

gem 'cocoapods', '~> 0.34.0'
gem 'cocoapods-cordova', :github => 'xdissent/cocoapods-cordova'
```

* Install gems:

```console
$ bundle install
```

* Create a `Podfile` and add dependencies:

```ruby
platform :ios, '7.0'

pod 'Cordova'             # Required
pod 'CordovaPlugin-file'  # Cordova plugin dependency
pod 'AFNetworking'        # Non-Cordova dependency

# Test target must not link against default pods (exclusive)
target 'HelloTests', :exclusive => true do
  pod 'OCMock'
end
```

* Install pods:

```console
$ bundle exec pod install
```

* Add Cordova plugin JS interface in `www` folder.

* Add "empty" Cordova `plugin.xml` (without specifying plugin files):

```xml
<?xml version='1.0' encoding='UTF-8'?>
<plugin xmlns='http://apache.org/cordova/ns/plugins/1.0' id='com.example.hello' version='0.0.1'>
  <name>Hello</name>
  <description>Cordova Hello Plugin</description>
  <license>MIT</license>
  <keywords>cordova,hello</keywords>
  <js-module src='www/hello.js' name='hello'>
    <clobbers target='Hello'/>
  </js-module>
  <dependency id='org.apache.cordova.file' url='https://github.com/apache/cordova-plugin-file.git' commit='r1.0.1'/>
  <platform name='ios'>
    <config-file target='config.xml' parent='/*'>
      <feature name='Hello'>
        <param name='ios-package' value='Hello'/>
      </feature>
    </config-file>
  </platform>
</plugin>
```

* Implement/Test plugin

* Build plugin:

```console
$ bundle exec pod cordova
```
