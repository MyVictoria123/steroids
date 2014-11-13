AppGyver Steroids CLI
---------------------

AppGyver Steroids is PhoneGap on Steroids, providing native UI elements, multiple WebViews and enhancements for better developer productivity.

## Installation and requirements

### Requirements

* Node.js 0.10.x and npm package management http://nodejs.org/

#### Windows

* Git ( http://git-scm.com/downloads )
* Python 2.7 or greater ( http://www.python.org/getit/ )

#### OS X

* Xcode and command-line tools (Mac App store)
* Git with homebrew or git Mac installer (if using the installer, remember to includ git in your $PATH)
* Python 2.7 or greater (preinstalled on OS X Lion and newer)

#### Linux

* Git
* Python 2.7 or greater

### Installing With Node Version Manager (for OS X and Linux)

We recommend installing with NVM, see [https://github.com/creationix/nvm](https://github.com/creationix/nvm): it allows you to run multiple versions of node and does not require sudo at any point.

    $ curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | sh

Note that by default NVM adds initialization lines to `.bash_profile`, so you need to make sure these lines are loaded.

To install node.js 0.10.x with nvm and set it as default:

    $ nvm install 0.10
    $ nvm use 0.10
    $ nvm alias default 0.10

Now install Steroids globally with the `-g` flag:

    $ npm install steroids -g

Note that some third-party npm packages might give warnings during the install project. These warnings shouldn't affect how the Steroids npm functions.

## Usage

    $ steroids create directory_name
    $ cd directory_name
    $ steroids connect

More usage information is available via

    $ steroids usage

## Development

After pulling from remote, to ensure all dependencies are updated properly:

    $ rm -rf node_modules

Install dependencies:

    $ npm install

Link your `devroids` folder into the global namespace:

    $ npm link

Run with `$ devroids` command.

## Documentation

[Steroids Developer Portal](http://developers.appgyver.com)

## Forums

[http://forums.appgyver.com](http://forums.appgyver.com)

## Bugs, feedback

We want to get your feedback! Drop us a mail at contact@appgyver.com

## Testing npm

To run unit tests:

    $ ./bin/test release    # release testing, also creates required __testApp
    $ ./bin/test fast       # skip time consuming tests
    $ ./bin/test            # full test suite, skip setup (release)
    $ ./bin/test path/to/spec.coffee

## Contributing

We gladly accept pull requests! However, include only one feature or fix per one pull request.
That way, it will be much easier to review and merge each one contribution.

To develop Steroids-npm locally:

* Clone this repo and install its dependencies (`npm install`).
* Create a symlink from `/usr/local/bin/devroids` to your development Steroids executable.
* Use `devroids` as you would use `steroids`.


## Statistics

[![NPM](https://nodei.co/npm-dl/steroids.png?height=3)](https://nodei.co/npm/steroids/)
