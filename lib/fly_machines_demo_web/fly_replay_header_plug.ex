defmodule FlyMachinesDemoWeb.Plugs.FlyReplayHeader do
  alias Plug.Conn

  require Logger

  def init(opts), do: opts

  # TODO start comparing the target and actual instance instead of relying on the headers
  def call(%Conn{path_info: ["gameserver" | path_info_tail]} = conn, _opts) do
    target_instance = hd(path_info_tail)

    already_replayed? =
      conn.req_headers
      |> Enum.map(fn
        {"fly-replay-src", _info} -> true
        _header -> false
      end)
      |> Enum.any?()

    if already_replayed? do
      Logger.info("This conn reached this instance after being replayed by the proxy.")
      Logger.info(inspect(conn))
      conn
    else
      Logger.info("This conn will ask the proxy to replay the request elsewhere.")
      resp_headers = [{"fly-replay", "region=#{target_instance}"} | conn.resp_headers]

      conn =
        conn
        |> Map.put(:resp_headers, resp_headers)
        # |> Conn.put_status(:not_found)
        # |> Phoenix.Controller.render(FlyMachinesDemoWeb.ErrorView, :"404")
        # |> Conn.halt()

      Logger.info(inspect(conn))
      conn
    end
  end

  def call(%Conn{} = conn, _opts), do: conn
end
