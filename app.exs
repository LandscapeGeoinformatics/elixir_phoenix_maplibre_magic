Application.put_env(:sample, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7.0"},
  {:phoenix_live_view, "~> 0.19.0"}
])

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    sources = %{
      openstreetmap: %{
        name: "OpenStreetMap",
        type: :raster,
        tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      },
      positron: %{
        name: "CartoDB Positron",
        type: :raster,
        tiles: ["https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png"],
      },
      darkmatter: %{
        name: "CartoDB Dark Matter",
        type: :raster,
        tiles: ["https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"],
      },
      satellite: %{
        name: "ESRI World Imagery",
        type: :raster,
        tiles: ["https://server.arcgisonline.com/arcgis/rest/services/world_imagery/mapserver/tile/{z}/{y}/{x}.png"],
      }
    }

    {:ok, assign(socket,
      sources: sources,
      active_maps: []
    )}
  end

  defp phx_vsn, do: Application.spec(:phoenix, :vsn)
  defp lv_vsn, do: Application.spec(:phoenix_live_view, :vsn)

  def render("live.html", assigns) do
    ~H"""
    <script src={"https://cdn.jsdelivr.net/npm/phoenix@#{phx_vsn()}/priv/static/phoenix.min.js"}></script>
    <script src={"https://cdn.jsdelivr.net/npm/phoenix_live_view@#{lv_vsn()}/priv/static/phoenix_live_view.min.js"}></script>
    <script src='https://unpkg.com/maplibre-gl@5.3.0/dist/maplibre-gl.js'></script>
    <script src="https://unpkg.com/@mapbox/mapbox-gl-sync-move@0.3.1"></script>
    <link rel='stylesheet' href='https://unpkg.com/maplibre-gl@5.3.0/dist/maplibre-gl.css' />
    <script>
      const mapSources = {
        openstreetmap: {
          type: "raster",
          tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"]
        },
        positron: {
          type: "raster",
          tiles: ["https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png"]
        },
        darkmatter: {
          type: "raster",
          tiles: ["https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"]
        },
        satellite: {
          type: "raster",
          tiles: ["https://server.arcgisonline.com/arcgis/rest/services/world_imagery/mapserver/tile/{z}/{y}/{x}.png"]
        }
      };

      const Hooks = {
        SyncMaps: {
          mounted() {
            console.log("SyncMaps hook mounted");
            this.maps = {};
            this.initializeMaps();
          },

          updated() {
            console.log("SyncMaps hook updated");
            // Clear existing maps since the DOM has changed
            Object.values(this.maps).forEach(map => map.remove());
            this.maps = {};
            this.initializeMaps();
          },

          initializeMaps() {
            console.log("Initializing maps...");
            const mapContainers = this.el.querySelectorAll('.map-container');

            // Initialize each map
            mapContainers.forEach(container => {
              const sourceId = container.dataset.source;
              const sourceData = mapSources[sourceId];

              if (!this.maps[sourceId]) {
                console.log(`Creating map for ${sourceId}`);

                // Create a style object
                const style = {
                  version: 8,
                  sources: {
                    [sourceId]: {
                      type: sourceData.type,
                      tiles: sourceData.tiles,
                      tileSize: 256
                    }
                  },
                  layers: [
                    {
                      id: `${sourceId}-layer`,
                      type: "raster",
                      source: sourceId,
                      minzoom: 0,
                      maxzoom: 22
                    }
                  ]
                };

                // Create the map
                this.maps[sourceId] = new maplibregl.Map({
                  container: container.id,
                  style: style,
                  center: [0, 0],
                  zoom: 2,
                  maplibreLogo: true
                });
              }
            });

            // Synchronize maps if there are at least 2 maps
            const mapIds = Object.keys(this.maps);
            if (mapIds.length >= 2) {
              console.log("Synchronizing maps");
              const mapsToSync = mapIds.map(id => this.maps[id]);
              syncMaps(...mapsToSync);
            }
          }
        }
      };

      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {hooks: Hooks})
      liveSocket.connect()
    </script>
    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
    <div style="
      display: flex;
      flex-direction: column;
      height: 100vh;
    ">
      <div style="
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        padding: 10px;
      ">
        <%= for {source_id, source_data} <- @sources do %>
          <button
            phx-click="toggle_map"
            phx-value-source={source_id}
            style={if source_id in @active_maps,
              do: "font-size: 1em; padding: 8px 16px; background-color: #4CAF50; color: white; border: 1px solid #ccc; border-radius: 4px; cursor: pointer;",
              else: "font-size: 1em; padding: 8px 16px; background-color: #f0f0f0; color: black; border: 1px solid #ccc; border-radius: 4px; cursor: pointer;"
            }>
            <%= source_data.name %>
          </button>
        <% end %>
      </div>

      <%= if length(@active_maps) > 0 do %>
        <div
          id="maps-container"
          phx-hook="SyncMaps"
          style="
            display: flex;
            flex: 1;
            width: 100%;
          ">
          <%= for source_id <- @active_maps do %>
            <div
              id={"map-#{source_id}"}
              class="map-container"
              data-source={source_id}
              style="
                flex: 1;
                height: 100%;
              "
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_map", %{"source" => source}, socket) do
    source_atom = String.to_existing_atom(source)
    active_maps = socket.assigns.active_maps

    # Check if the map is already active
    updated_maps = if source_atom in active_maps do
      List.delete(active_maps, source_atom)
    else
      active_maps ++ [source_atom]
    end

    {:noreply, assign(socket, active_maps: updated_maps)}
  end
end


defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)

    live("/", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)
  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)
