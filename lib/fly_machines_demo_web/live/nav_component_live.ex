defmodule FlyMachinesDemoWeb.NavComponentLive do
  use FlyMachinesDemoWeb, :live_component

  @regions %{"ewr" => "🇺🇸", "nrt" => "🇯🇵", "cdg" => "🇫🇷"}

  def get_flag(region), do: @regions |> Map.get(region, "🚩")

  def get_flag(), do: @regions |> Map.get(System.get_env("FLY_REGION", nil), "🚩")

end
