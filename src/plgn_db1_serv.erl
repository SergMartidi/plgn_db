%% @author Admin
%% @doc @todo Add description to plgn_db1_serv.


-module(plgn_db1_serv).
-behaviour(gen_server).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2, command/1, stop/0]).

-record(state, {ip , socket, pid, reqpid=[], subpid=[]}).



%% ====================================================================
%% Internal functions
%% ====================================================================


start_link(IP) -> 
	case ipcheck(IP) of
		true -> gen_server:start_link({local, ?MODULE}, ?MODULE, IP, []);
		false -> io:format("Error! Invalid IP address\n"), {error, invalid_ip}
	end.

init(IP) -> 
	process_flag(trap_exit, true),
    case startsup(IP) of
		{ok, Socket} -> 
			self() ! subscribe, 
			link(whereis(chumak_sup)),
			ChumakPid=whereis(chumak_sup),
			timer:sleep(100),
			io:format("Connection established\n"),
			{ok, #state{ip=IP, socket=Socket, reqpid=[ChumakPid]}};
              _     -> {stop, normal}
	end.

handle_call({check, FunArgs}, _From, S=#state{socket=Socket}) ->
	Reply=command(Socket, FunArgs),
	case Reply of 
		{error, frame_error} -> io:format("Error! Application will be reloaded\n"), {stop, normal, S};
		                  _  -> {reply, Reply, S}
    end;

handle_call(stop, _From, State) ->
	{stop, normal, ok, State};

handle_call(_, _From, State) ->
	{reply, ok, State}.

handle_cast(_, State) ->
	{noreply, State}.
 
handle_info(subscribe, S=#state{ip=IP, pid=OldPid}) ->
	case OldPid of
		undefined ->
	      Pid=plgn_db1_subscribe:start_link(connect, [IP]),
	      {noreply, S#state{pid=Pid}};
		     _ -> {noreply, S}
	end;

handle_info({reqpid, Pid}, S=#state{reqpid=ReqPid}) ->
	link(Pid),
	NewReqPid=[Pid|ReqPid],
	{noreply, S#state{reqpid=NewReqPid}};

handle_info({subpid, Pid}, S=#state{subpid=SubPid}) ->
	link(Pid),
	NewSubPid=[Pid|SubPid],
	{noreply, S#state{subpid=NewSubPid}};

handle_info({'EXIT',_ , close}, S) ->
	{noreply, S};

handle_info({'EXIT', ProcPid, _}, S) ->
	case lists:member(ProcPid, S#state.reqpid) of
		true -> io:format("Error! Application will be reloaded\n"), {stop, normal, S};
		false -> 
			case lists:member(ProcPid, S#state.subpid) of
				true ->  
					exit(S#state.pid, close),
					self() ! subscribe, 
					{noreply, S#state{pid=undefined}};
				false -> {noreply, S}
            end
	end;

handle_info(_, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

terminate(_Reason, #state{pid=Pid}) -> 
	exit(Pid, shutdown),
	ok.

command(FunArgs) -> 
    gen_server:call(plgn_db1_serv, {check, FunArgs}, 20000).

stop() -> 
    gen_server:call(plgn_db1_serv, stop).


startsup(IP) ->
   process_flag(trap_exit, true), 
   Pid=plgn_db1_main:start_link(start, [IP]), 
   receive
	    {start, ok, Socket} -> {ok, Socket};
		{peer, {error, Reason}} ->  io:format("Couldn't connect to server, reason: ~p~n", [Reason]),
									application:stop(chumak), 
									{error, Reason};
	    {start, {error, Reason}} ->  io:format("Couldn't connect to server, reason: ~p~n", [Reason]),
									application:stop(chumak), 
									{error, Reason};
		{'EXIT', Pid, _} -> io:format("Couldn't connect to server\n"), 
									 application:stop(chumak), 
									 {error, connfailed}   
   end.


command(Socket, FunArgs) ->
     process_flag(trap_exit, true),
	 Pid=apply(plgn_db1_main, start_link, FunArgs),
	 commsup(Socket, Pid, false).	

commsup(Socket, Pid, FrameSentFlag) -> 
   receive 
	  {Pid, Ref, socket} -> Pid ! {Ref, Socket}, commsup(Socket, Pid, FrameSentFlag); 
	  {result, Result} -> Result; 
     {'EXIT', Pid, _} -> io:format("Error! Couldn't send information to server\n"), {error, msgnotsend};
     {frame, sent} -> commsup(Socket, Pid, true)   
   after 3000 -> 
     case FrameSentFlag of
		 false -> io:format("Error! Couldn't connect to server. Trying to reconnect...\n"),  {error, no_connection};
	     true  -> io:format("Error! Couldn't connect to server\n"), {error, frame_error}
	 end
   end.

ipcheck(IP) -> ipcheck(IP, [], 0).
ipcheck([], [], _) -> false;
ipcheck([], L, 3) -> case  list_to_integer(L)>=0 andalso list_to_integer(L)=<255 of 
						 true -> true;
						 false -> false
					 end;
ipcheck([], _, _) -> false;
ipcheck([46|_], [], _)  -> false;
ipcheck([46|T], L, PN) -> case list_to_integer(L)>=0 andalso list_to_integer(L)=<255 of
							 true -> ipcheck(T, [], PN+1);
							 false -> false
						  end;
ipcheck([H|T], L, PN) when H>=48, H=<57 -> ipcheck(T, L++[H], PN);
ipcheck([_|_], _, _) -> false.	

     