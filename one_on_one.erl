-module(one_on_one).

-export([create_player/1, player/1, timer/2, main/0, stealing/1, init_player/1]).

-type player_state() :: #{name => string()
                          , other_player => list()
                          , ball => boolean()
                          , player_stats => player_stats()
                          , processes => process_state()
                         }.
-type player_stats() :: #{ball_protection => number(), stealing => number()}.
-type process_state() :: #{stealing_process => pid()}.

init_player(State) ->
  receive
    {add_opponent, PlyerPid} -> player(maps:put(other_player, PlyerPid, State));
    _ -> ok
  end.


-spec player(State) -> Ret when
    State :: player_state(),
    Ret :: term().
player(#{ball := false, processes := #{stealing_process := nil} = Processes} = State) ->
  Pid = spawn(?MODULE, stealing, [State]),
  player(maps:put(processes
                  , maps:put(stealing_process, Pid, Processes)
                  , State));

player(#{name := Name, other_player := OtherPlayer
        , processes := #{stealing_process := StealingProcess} = Processes 
        } = State) ->
  receive
    steal -> case is_ball_stolen(State) of
               true -> print("I lost the ball", [Name])
                       , OtherPlayer ! get_ball
                       , player(maps:put(ball, false, State));
               false -> print("I protected the ball", [Name])
                        , player(State)
             end, player(State);
    get_ball -> print("I got the ball.", [Name])
                % need to set the stealing_process to nil, because the above clause matches for that
                , exit(StealingProcess, kill)
                , player(maps:put(ball
                                  , true
                                  , maps:put(processes
                                             , maps:put(stealing_process, nil, Processes)
                                             , State)));
    timeout -> print("Im out.", [Name]), exit(normal)
  end.

stealing(#{other_player := PlayerFrom, ball := _, player_stats := PlayerStats} = State) ->
  timer:sleep(500),
  #{stealing := Stealing} = PlayerStats,
  Random = rand:uniform(5),
  case Stealing + Random > 7 of
    true -> PlayerFrom ! steal;
    false -> stealing(State)
  end,
  stealing(State).

-spec is_ball_stolen(State) -> Ret when
    State :: player_state(),
    Ret :: boolean().
is_ball_stolen(#{ball := false}) -> false;
is_ball_stolen(#{player_stats := #{ball_protection := BallProtection}}) ->
  Random = rand:uniform(10),
  % io:format(user, "Random number:~p~n", [Random]),
  case BallProtection + Random of
    Result when Result > 12 -> false;
    _ -> true
  end.

create_player(PlayerState) ->
  Pid = spawn(?MODULE, init_player, [PlayerState]),
  Pid.

timer(0, Players) ->
  lists:map(
    fun(Player) ->
        Player ! timeout
    end,
    Players
   );
timer(Time, Players) ->
  timer:sleep(1000),
  % print("Time left:", Time - 1),
  timer(Time - 1, Players).

main() ->
  Player1 = create_player(#{
                            name => "Edwards"
                            , other_player => nil
                            , ball => true
                            , player_stats => #{
                                              ball_protection => 4,
                                              stealing => 5
                                             }
                            , processes => #{
                                             stealing_process => nil
                                            }
                           }),
  Player2 = create_player(#{
                            name => "Brown"
                            , other_player => nil
                            , ball => false
                            , player_stats => #{
                                              ball_protection => 2,
                                              stealing => 3
                                             }
                            , processes => #{
                                             stealing_process => nil
                                            }
                           }),

  Player1 ! {add_opponent, Player2},
  Player2 ! {add_opponent, Player1},

  spawn(?MODULE, timer, [5, [Player1, Player2]]).


% ------------ UTILS ------------

print(Message, Param) ->
  io:format(user, "Message:~p , Param: ~p~n", [Message, Param]).
