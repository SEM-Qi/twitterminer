# DIT029 Twitter Miner

This is a demonstrator Twitter streaming API client for the DIT029 course at [Gothenburg University](http://www.gu.se).

**License:** This software is released into the public domain (see `LICENSE`).

**Current Version:** 0.1

## Quickstart guide

1.  Get Erlang

    You really need an Erlang installation to run this project.

1.  Get Rebar

    Rebar is a build script for Erlang projects. You may install it from your distribution packages, or get it from here:

    https://github.com/basho/rebar

1.  Clone the repo

        $ git clone https://github.com/michalpalka/dit029-twitter-miner.git

1.  Get the dependencies

        $ cd dit029-twitter-miner/
        $ rebar get-deps

1.  Compile the dependencies and the package

        $ rebar compile

1.  Get a Twitter account and generate authentication keys
    (We have this already, check the Google drive under technical documentation. Be aware that I dont know if we can simultaneously access the stream with these credentials)

    1.  Open a Twitter account at https://twitter.com .

    1.  Go to https://apps.twitter.com and create a new app.

    1.  Generate API keys for the app using the API Keys tab, as described
        [here](https://dev.twitter.com/oauth/overview/application-owner-access-tokens).

    1.  Collect the `API key`, `API secret`, `Access token` and `Access token secret`,
        and put them into the `twitterminer.config` file, which you find in the repo's
        toplevel directory.

1.  Run the example

    Run the Erlang shell from the repo's toplevel directory with additional library path and configuration flags

        $ erl -pa deps/*/ebin -pa ebin -config twitterminer

    Start all needed Erlang applications in the shell

    ```erlang
    1> application:ensure_all_started(twitterminer).
    ```

    Note that the previous step requires Erlang/OTP 16B02 or newer. If you have an older installation, you have to start them manually, as follows (see [this](http://stackoverflow.com/questions/10502783/erlang-how-to-load-applications-with-their-dependencies) for more information):

    ```erlang
    1> [application:start(A) || A <- [asn1, crypto, public_key, ssl, ibrowse, twitterminer]].
    ```

    Now you are ready to run your example as below. The first argument is the number of milliseconds you wish to run the miner for, the second is the minimum frequency required for a tag to be printed at the end. Here it is ten minutes with only tags occuring 3 or more times being printed.

    ```erlang
    2> twitterminer_source:twitter_example(600000, 3).
    ```

    If everything goes OK, you should see a stream of tweets running for your specified time. If you get a message indicating HTTP response code 401, it probably means authentication error. Due to a known bug (unrelated to any HTTP error), please restart the shell before attempting to reconnect to Twitter.

## Dependencies

### [erlang-oauth](https://github.com/tim/erlang-oauth/)

erlang-oauth is used to construct signed request parameters required by OAuth.

### [ibrowse](https://github.com/cmullaparthi/ibrowse)

ibrowse is an HTTP client allowing to close a connection while the request is still being serviced. We need this for cancelling Twitter streaming API requests.

### [jiffy](https://github.com/davisp/jiffy)

jiffy is a JSON parser, which uses efficient C code to perform the actual parsing. [mochijson2](https://github.com/bjnortier/mochijson2) is another alternative that could be used here.

## Author

* Michał Pałka (michalpalka) <michal.palka@chalmers.se>

