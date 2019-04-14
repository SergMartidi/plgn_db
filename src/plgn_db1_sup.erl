%%%-------------------------------------------------------------------
%% @doc plgn_db1 top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(plgn_db1_sup).



%% API
-export([start_link/2, msg_clear/0]).

-export([init/2]).


%-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================


start_link(Mod, FunArgs) ->
	init(Mod, FunArgs).



%%====================================================================
%% Internal functions
%%====================================================================

init(Mod, FunArgs=[Fun, Args]) ->
	Subsupexists=lists:member(subsup, registered()),
    case Mod of 
		subscribe -> 
			process_flag(trap_exit, true),
			catch unregister(subsup),
            register(subsup, self()),
        	[IP, Socket] = Args,
            PidSub=apply(Mod, start_link, [connect, [IP]]),
            sub(IP, Socket, PidSub);
		_ when Fun==start -> 
			[IP]=Args,
			startsup(IP);
        _ when Subsupexists==false ->
			io:format("Error! Application hasn't started\n"),
			{error, appnotstarted};
		_ -> 
			msg_clear(), 
            process_flag(trap_exit, true),
			catch register(shell, self()),
			Pid=apply(Mod, start_link, FunArgs),
			commsup(Pid, false)			 
    end.


startsup(IP) ->
	case	main:ipcheck(IP) of
     true  -> catch unregister(shell), 
		     register(shell, self()),
			 msg_clear(), 
			 process_flag(trap_exit, true), 
			 Pid=main:start_link(start, [IP]), 
			 receive
				{start, ok} -> ok;
				{peer, {error, Reason}} ->  io:format("Couldn't connect to server, reason: ~p~n", [Reason]),
									plgn_db1:stop(), {error, Reason};
			    {start, {error, Reason}} ->  io:format("Couldn't connect to server, reason: ~p~n", [Reason]),
									plgn_db1:stop(), {error, Reason};
				 {'EXIT', Pid, _} -> io:format("Couldn't connect to server\n"), plgn_db1:stop(), {error, connfailed}
			 end;
	 false -> io:format("Error! Invalid IP address\n"), {error, invalid_ip}
   end.


sub(IP, Socket, PidSub) ->
   receive
	 {'EXIT', PidSub, _} -> apply(subscribe, start_link, [IP]), sub(IP, Socket, PidSub);  
	 {Pid, Ref, socket} -> Pid ! {Ref, Socket}, sub(IP, Socket, PidSub);
     shutdown  -> exit(shutdown)  
   end.  

commsup(Pid, FrameSentFlag) -> 
   receive 
	  {result, Result} -> Result; 
     {'EXIT', Pid, _} -> io:format("Error! Couldn't send information to server\n"), {error, msgnotsend};
     {frame, sent} -> commsup(Pid, true)   
   after 3000 -> 
     case FrameSentFlag of
		 false -> io:format("Error! Couldn't connect to server. Trying to reconnect...\n"),  {error, no_connection};
	     true  -> io:format("Error! Couldn't connect to server\n"), plgn_db1:stop()
	 end
   end.
     

msg_clear() ->
   receive
     _ -> msg_clear()
   after 0 -> ok
   end.









