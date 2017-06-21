%%%-------------------------------------------------------------------
%%% @author Stefan Hagdahl
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 12. Feb 2017 00:38
%%%-------------------------------------------------------------------
-module(eda_rest_api).
-author("Stefan Hagdahl").

%% API
-export([send_channel_message/4,
         create_channel_message/2,
         create_channel_message/3,
         create_embed_object/4,
         create_embed_fields/1,
         parse_http_headers/1]).

-export_type([http_method/0]).

-include("eda_rest.hrl").

-type http_method() :: get | put | patch | delete | post.

%%--------------------------------------------------------------------
%% Create Object for API
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Create Body for API
%%--------------------------------------------------------------------
%%--------------------------------------------------------------------
%% @doc
%% Send channel message
%%
%% @end
%%--------------------------------------------------------------------
-spec(send_channel_message(HttpMethod :: http_method(), Path :: string(),
                           Body :: iodata(),
                           BotName :: atom() | string()) ->
    {ok, Ref :: term()} | {error, Reason :: term()}).
send_channel_message(HttpMethod, Path, Body, BotName) ->
    eda_rest_path:rest_call(BotName, HttpMethod, Path, Body).

%%--------------------------------------------------------------------
%% @doc
%% Create Message
%% https://discordapp.com/developers/docs/resources/channel#create-message
%%
%% @end
%%--------------------------------------------------------------------
-spec(create_channel_message(ChannelId :: term(), Content :: string()) ->
    {HttpMethod :: http_method(), Path :: string(), Body :: iodata()} |
    {error, Reason :: term()}).
create_channel_message(ChannelId, Content) ->
    create_channel_message(ChannelId, Content, undefined).

%%--------------------------------------------------------------------
%% @doc
%% Create Message
%% https://discordapp.com/developers/docs/resources/channel#create-message
%%
%% @end
%%--------------------------------------------------------------------
-spec(create_channel_message(ChannelId :: term(), Content :: string(),
                     Embed :: map() | undefined) ->
    {HttpMethod :: http_method(), Path :: string(), Body :: iodata()} |
    {error, Reason :: term()}).
create_channel_message(ChannelId, Content, Embed) ->
    Path = ?RestCreateMessage(ChannelId),
    Body =
    case Embed of
        undefined ->
            #{<<"content">> => unicode:characters_to_binary(Content)};
        Embed when is_map(Embed) ->
            #{<<"content">> => unicode:characters_to_binary(Content),
                <<"embed">> => Embed}
    end,
    {post, Path, jiffy:encode(Body, [force_utf8])}.

%%--------------------------------------------------------------------
%% @doc
%% Create embed object for message
%% https://discordapp.com/developers/docs/resources/channel#embed-object
%%
%% @end
%%--------------------------------------------------------------------
-spec(create_embed_object(Title :: string(), Color :: integer(),
                          Description :: string() | undefined,
                          Fields :: [#{name => string(),
                                       value => string()}])
                         -> map()).
create_embed_object(Title, Color, Description, Fields) ->
    #{<<"title">> => unicode:characters_to_binary(Title),
      <<"color">> => Color,
      <<"description">> => unicode:characters_to_binary(Description),
        <<"fields">> => create_embed_fields(Fields)}.

%%--------------------------------------------------------------------
%% @doc
%% Create embed fields
%%
%% @end
%%--------------------------------------------------------------------
-spec(create_embed_fields(Fields :: [#{name => string(),
                                       value => string()}]) ->
    [#{name => bitstring(), value => bitstring()}]).
create_embed_fields(Fields) ->
    create_embed_fields(Fields, []).

create_embed_fields([], Fields) ->
    Fields;
create_embed_fields([#{name := Name, value := Value}|Rest], Fields) ->
    FieldMap = #{name => unicode:characters_to_binary(Name),
                 value => unicode:characters_to_binary(Value)},
    create_embed_fields(Rest, Fields ++ [FieldMap]).


%%--------------------------------------------------------------------
%% @doc
%% Parse http headers
%%
%% @end
%%--------------------------------------------------------------------
-spec(parse_http_headers(Headers :: [bitstring()]) ->
    ParsedHeaders :: #{}).
parse_http_headers(Headers) ->
    parse_http_headers(Headers, #{}).

%%%===================================================================
%%% Internal functions
%%%===================================================================
parse_http_headers([], ParsedHeaders) ->
    ParsedHeaders;
parse_http_headers([{?RestRateLimit, Limit}| Rest], ParsedHeaders) ->
    ConvertedLimit = list_to_integer(bitstring_to_list(Limit)),
    UpdatedParsedHeader = maps:put(rate_limit, ConvertedLimit, ParsedHeaders),
    parse_http_headers(Rest, UpdatedParsedHeader);
parse_http_headers([{?RestRateLimitGlobal, Global}| Rest], ParsedHeaders) ->
    ConvertedGlobal = list_to_atom(bitstring_to_list(Global)),
    UpdatedParsedHeader = maps:put(rate_limit_global, ConvertedGlobal,
                                   ParsedHeaders),
    parse_http_headers(Rest, UpdatedParsedHeader);
parse_http_headers([{?RestRateLimitRemaining, Remaining}| Rest], ParsedHeaders) ->
    ConvertedRemaining = list_to_integer(bitstring_to_list(Remaining)),
    UpdatedParsedHeader = maps:put(rate_limit_remaining, ConvertedRemaining,
                                   ParsedHeaders),
    parse_http_headers(Rest, UpdatedParsedHeader);
parse_http_headers([{?RestRateLimitReset, Reset}| Rest], ParsedHeaders) ->
    ConvertedReset = list_to_integer(bitstring_to_list(Reset)),
    UpdatedParsedHeaders = maps:put(rate_limit_reset, ConvertedReset,
                                    ParsedHeaders),
    parse_http_headers(Rest, UpdatedParsedHeaders);
parse_http_headers([_| Rest], ParsedHeaders) ->
    parse_http_headers(Rest, ParsedHeaders).