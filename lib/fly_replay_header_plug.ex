defmodule FlyReplayHeaderPlug do
  alias Plug.Conn

  def init(opts), do: opts

  def call(%Conn{path_info: ["gameserver" | path_info_tail]} = conn, _opts) do
    instance = hd(path_info_tail)
    %Conn{conn | req_headers: [{"fly-replay", "region=#{instance}"} | conn.req_headers]}
  end

  def call(%Conn{} = conn, _opts), do: conn
end
