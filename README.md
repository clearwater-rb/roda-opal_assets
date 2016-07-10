# Roda::OpalAssets

Simple compilation for Opal apps on the Roda web framework for Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'roda-opal_assets'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install roda-opal_assets

## Usage

In your Roda app:

```ruby
class App < Roda
  assets = Roda::OpalAssets.new

  route do |r|
    assets.route r

    # Other routes here
  end

  define_method(:js)         { |file| assets.js file }
  define_method(:stylesheet) { |file| assets.stylesheet file }
end
```

Then you can put your Ruby and JS assets in `assets/js` and your stylesheets in `assets/css`.

Inside your views, you just need to call the `js` and `stylesheet` methods above.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/clearwater-rb/roda-opal_assets. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
