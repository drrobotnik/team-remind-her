hubot-bitly
=============

Shorten URLs with bit.ly & expand detected bit.ly URLs

## Installation

* Run the `npm install` command.

```
$ npm install hubot-bitly
```

* Add the following code in your `external-scripts.json` file.

```
["hubot-bitly"]
```

## Configuration

```
HUBOT_BITLY_ACCESS_TOKEN
```

## Sample Interaction

```
hubot remind me in `time` to `action` - Set a reminder in `time` to do an `action` `time` is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
hubot remind `user` in `time` to `action` - Set a reminder in `time` to do an `action` `time` is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
```