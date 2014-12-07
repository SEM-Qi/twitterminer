-module(twitterminer_crunchtags).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/1]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link(RiakIP) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, RiakIP, []).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([RiakIP]) ->
	io:format("Starting riak conn crunch tags"),
	try riakc_pb_socket:start_link(RiakIP, 8087) of
    {ok, RiakPID} ->
    	{ok, RiakPID}
	
	catch
    	_ ->
      		exit("no_riak_connection")
  	end.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% Pseudo code for twitterminer_crunchtags. Do map and reduce on a continuous timed loop on data that twitterminer_updatelist has gathered. 	
%% -receive signal (or "tick") in a handle_cast function (look at the existing modules)
handle_cast(tick, RiakPID) ->
  ListOfTags = case riakc_pb_socket:get(RiakPID, <<"taglistbucket">>, <<"taglist">>) of
    {ok, List} -> 
        FinalTaglist = binary_to_term(riakc_obj:get_value(List)),  
        FinalTaglist;
    Reason -> exit(Reason)
  end,
  CrunchedTags = lists:map(crunch_tags(Tag), ListOfTags),
  put_to_riak(CrunchedTags, RiakPID),
  {noreply, RiakPID};
  

%% Instead of returning a callback for the data server at the end of the function, you put that data structure in riak, as above.


%% -wait for next tick. This will happen automatically as you should be using an OTP gen_server. 
	



handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

loopThrough([], L, Cotags) -> {L, sets:to_list(Cotags)};
loopThrough(Tagset, L, OldCotags) ->
  {NewKeys,OldKeys} = lists:split(2, Tagset),
  [{Num, Cotags, Tweets}, {Num2, Cotags2, Tweets2}] = NewKeys,
  L2 = [{[{<<"numtags">>, Num + Num2}, {<<"tweets">>, sets:to_list(sets:union([Tweets, Tweets2]))}]}|L],
  NewCotags = sets:union([Cotags, Cotags2, OldCotags]),
  loopThrough(OldKeys, L2, NewCotags).

timeStamp() ->
  {Mega, Secs, Micro} = erlang:now(),
  Mega*1000*1000*1000*1000 + Secs * 1000 * 1000 + Micro.

oldTimeStamp() ->
  {Mega, Secs, Micro} = erlang:now(),
  Mega*1000*1000*1000*1000 + ((Secs - 2400) * 1000 * 1000) + Micro.

crunch_tags(Tag) ->
  {Distribution, Cotags} = case riakc_pb_socket:get_index_range(
            SocketPid,
            <<"tags">>, %% bucket name
            {integer_index, "timestamp"}, %% index name
            oldTimeStamp(), timeStamp() %% origin timestamp should eventually have some logic attached
          ) of
    {ok, {_,Keys,_,_}} ->
      AllKeys = lists:reverse(lists:sort(Keys)),
      if
        length(AllKeys) >= 20 ->
          {NewKeys,_} = lists:split(20, AllKeys),
          Objects = lists:map(fun(Key) -> {ok, Obj} = riakc_pb_socket:get(SocketPid, <<"tags">>, Key), Obj end, NewKeys),
          Tagset = lists:map(fun(Object) -> Value = binary_to_term(riakc_obj:get_value(Object)), case dict:find(Tag, Value) of {ok, Tagged} -> Tagged; error -> {0, sets:new(),sets:new()} end end, Objects),
          {Distribution1, Cotags1} = loopThrough(Tagset, [], sets:new()),
          {Distribution1, Cotags1};
        (length(AllKeys) >= 2) and (length(AllKeys) rem 2 =:= 0) ->
          Objects = lists:map(fun(Key) -> {ok, Obj} = riakc_pb_socket:get(SocketPid, <<"tags">>, Key), Obj end, AllKeys),
          Tagset = lists:map(fun(Object) -> Value = binary_to_term(riakc_obj:get_value(Object)), case dict:find(Tag, Value) of {ok, Tagged} -> Tagged; error -> {0, sets:new(),sets:new()} end end, Objects),
          {Distribution1, Cotags1} = loopThrough(Tagset, [], sets:new()),
          {Distribution1, Cotags1};
        length(AllKeys) >= 2 ->
          [_|NewKeys] = AllKeys,
          Objects = lists:map(fun(Key) -> {ok, Obj} = riakc_pb_socket:get(SocketPid, <<"tags">>, Key), Obj end, NewKeys),
          Tagset = lists:map(fun(Object) -> Value = binary_to_term(riakc_obj:get_value(Object)), case dict:find(Tag, Value) of {ok, Tagged} -> Tagged; error -> {0, sets:new(),sets:new()} end end, Objects),
          {Distribution1, Cotags1} = loopThrough(Tagset, [], sets:new()),
          {Distribution1, Cotags1};
        true ->
          {[{[{<<"numtags">>, 0}, {<<"tweets">>, ""}]}],[]}
      end;
    {error, _} ->
      {[{[{<<"numtags">>, 0}, {<<"tweets">>, ""}]}],[]}
  end,
  Value = jiffy:encode({[{<<"tag">>, Tag},
  {<<"cotags">>, Cotags},
  {<<"distribution">>, 
    Distribution}]}),
  {Tag, Value}.

  put_to_riak([], RiakPid) -> ok; 
  put_to_riak([H|T], RiakPid) -> 
    {Tag, Value} = H,
    PutTagValue = riakc_obj:new(<<"formattedtweets">>,
                          Tag,
                          term_to_binary(Value)),

    riakc_pb_socket:put(RiakPid, PutTagValue),
    put_to_riak(T, RiakPid).