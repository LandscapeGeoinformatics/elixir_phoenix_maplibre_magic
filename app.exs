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

  def styles(), do: %{
  "openstreetmap" => %{
    version: 8,
    sources: %{
      "openstreetmap" => %{
        type: "raster",
        tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
        tileSize: 256,
        attribution: "© OpenStreetMap contributors"
      }
    },
    layers: [
      %{
        id: "openstreetmap-background",
        type: "raster",
        source: "openstreetmap",
        minzoom: 0,
        maxzoom: 19
      }
    ]
  },
  "positron" => %{
    version: 8,
    sources: %{
      "positron" => %{
        type: "raster",
        tiles: ["https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png"],
        tileSize: 256,
        attribution: "© CARTO"
      }
    },
    layers: [
      %{
        id: "positron-background",
        type: "raster",
        source: "positron",
        minzoom: 0,
        maxzoom: 19
      }
    ]
  },
  "darkmatter" => %{
    version: 8,
    sources: %{
      "darkmatter" => %{
        type: "raster",
        tiles: ["https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"],
        tileSize: 256,
        attribution: "© CARTO"
      }
    },
    layers: [
      %{
        id: "darkmatter-background",
        type: "raster",
        source: "darkmatter",
        minzoom: 0,
        maxzoom: 19
      }
    ]
  },
  "satellite" => %{
    version: 8,
    sources: %{
      "satellite" => %{
        type: "raster",
        tiles: ["https://server.arcgisonline.com/arcgis/rest/services/world_imagery/mapserver/tile/{z}/{y}/{x}.png"],
        tileSize: 256,
        attribution: "© ESRI"
      }
    },
    layers: [
      %{
        id: "satellite-background",
        type: "raster",
        source: "satellite",
        minzoom: 0,
        maxzoom: 19
      }
    ]
  },

  "tartu_spiral" => %{
    version: 8,
    sources: %{
      "openstreetmap" => %{
        type: "raster",
        tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
        tileSize: 256,
        attribution: "© OpenStreetMap contributors"
      },
      "tartu-spiral" => %{
        type: "geojson",
        data: generate_tartu_spiral()
      }
    },
    layers: [
      %{
        id: "openstreetmap-background",
        type: "raster",
        source: "openstreetmap",
        minzoom: 0,
        maxzoom: 19
      },
      %{
        id: "tartu-spiral-overlay",
        type: "line",
        source: "tartu-spiral",
        layout: %{
          "line-join" => "round",
          "line-cap" => "round"
        },
        paint: %{
          "line-color" => "#FF0000",
          "line-width" => 15,
          "line-opacity" => 0.2
        }
      }
    ]
  }

  
}

  # Generate spiral GeoJSON centered on Tartu
  def generate_tartu_spiral do
    tartu_coordinates = [26.71626471, 58.37334855] # [longitude, latitude]
    number_of_points = 20000 # ~ resolution
    maximal_radius = 10 # degrees
    
    # Create spiral points
    spiral_coords = Enum.map(0..(number_of_points - 1), fn i ->
      # Use a smaller angle increment for smoother rotation
      angle = 0.05 * i
      
      # Non-linear radius growth - increases spacing between outer spires
      normalized_i = i / number_of_points
      radius = :math.pow(normalized_i, 20) * maximal_radius
      
      # Convert polar to cartesian coordinates
      x = Enum.at(tartu_coordinates, 0) + radius * :math.cos(angle)
      y = Enum.at(tartu_coordinates, 1) + radius * :math.sin(angle)
      
      [x, y]
    end)
    
    # Create a GeoJSON LineString
    %{
      type: "Feature",
      properties: %{},
      geometry: %{
        type: "LineString",
        coordinates: spiral_coords
      }
    }
  end

  def mount(_params, _session, socket) do
    style_keys = MapSet.new(["openstreetmap", "positron", "darkmatter", "satellite", "tartu_spiral"])
    socket = assign(socket, 
      style_keys: style_keys, 
      active_style_keys: MapSet.new([])
    )

    {:ok, socket}
  end

  defp phx_vsn, do: Application.spec(:phoenix, :vsn)
  defp lv_vsn, do: Application.spec(:phoenix_live_view, :vsn)

  def render("live.html", assigns) do
    ~H"""
    <script src={"https://cdn.jsdelivr.net/npm/phoenix@#{phx_vsn()}/priv/static/phoenix.min.js"}></script>
    <script src={"https://cdn.jsdelivr.net/npm/phoenix_live_view@#{lv_vsn()}/priv/static/phoenix_live_view.min.js"}></script>
    <script src='https://unpkg.com/maplibre-gl@5.3.0/dist/maplibre-gl.js'></script>
    <link rel='stylesheet' href='https://unpkg.com/maplibre-gl@5.3.0/dist/maplibre-gl.css' />
    <script>
      all_maps = new Set([]);

      function moveToMapPosition(master, clones) {
        var center = master.getCenter();
        var zoom = master.getZoom();
        var bearing = master.getBearing();
        var pitch = master.getPitch();

        clones.forEach(function(clone) {
          clone.jumpTo({
            center: center,
            zoom: zoom,
            bearing: bearing,
            pitch: pitch
          });
        });
      }

      function synchrornize_maps() {
        var maps;
    
        if (arguments.length === 1) {
          maps = arguments[0];
        } else {
          maps = [];
          for (var i = 0; i < arguments.length; i++) {
            maps.push(arguments[i]);
          }
        }

        // Create all the movement functions
        var movement_functions = [];
        maps.forEach(function(map, index) {
          movement_functions[index] = sync.bind(null, map, maps.filter(function(o, i) { return i !== index; }));
        });

        function on() {
          maps.forEach(function(map, index) {
            map.on('move', movement_functions[index]);
          });
        }

        function off() {
          maps.forEach(function(map, index) {
            map.off('move', movement_functions[index]);
          });
        }

        // When one map moves, turn off listeners, move other maps, turn listeners back on
        function sync(master, clones) {
          off();
          moveToMapPosition(master, clones);
          on();
        }

        on();
        return function() { off(); movement_functions = []; maps = []; };
      }


      function spin_maps() {
        if (all_maps.size === 0) return;
  
        const duration = 3000 + Math.random() * 2000; // 3-5 seconds
        const rotations = 1 + Math.random() * 2; // 1-3 rotations
        const targetBearing = 360 * rotations;
  
        const startTime = performance.now();
        const startBearing = Array.from(all_maps)[0].getBearing();
  
        function animate(currentTime) {
          const elapsed = currentTime - startTime;
          const progress = Math.min(elapsed / duration, 1);
    
          // Smooth easing
          const easeProgress = 1 - Math.pow(1 - progress, 3);
          const currentBearing = startBearing + (targetBearing * easeProgress);
    
          Array.from(all_maps)[0].setBearing(currentBearing);
    
          if (progress < 1) {
            requestAnimationFrame(animate);
          }
          Array.from(all_maps)[0].flyTo({
            center: [26.71626471, 58.37334855],
            zoom: 7,
            essential: true,
            speed: 5,
            curve: 1,
            easing(t) { return t;}
          })

        }
  
        requestAnimationFrame(animate);
      }

      const Hooks = {
        one_map: {
          mounted() {
            const this_map_context = this;
            console.log(
             "handling initialize_map",
            );
    
            this_map_context.map_instance = new maplibregl.Map({
              container: this_map_context.el.id,
              style: {
                version: 8,
                sources: {},
                layers: [],
              },
              center: [0, 0],
              zoom: 1,
              attributionControl: false,
            });
      
            this_map_context.map_instance.on('error', (event) => {
              console.error('Map error:', event);
            });
      
            this_map_context.map_instance.on('load', () => {
              console.log("Map loaded, full style:", this_map_context.map_instance.getStyle());
              all_maps.add(this_map_context.map_instance); // Use add method of Set directly
              if (all_maps.size > 1) synchrornize_maps(Array.from(all_maps));
              this_map_context.pushEvent("map_instance_loaded", {container_id: this_map_context.el.id});
            });
    
            this_map_context.handleEvent(`update_map_${this_map_context.el.id}`, (payload) => {
              console.log(
               "handling update_map",
               payload
              );
              const map_style = payload.style;
              this_map_context.map_instance.setStyle(map_style);
            });
            this_map_context.handleEvent(`switch_projection_map_${this_map_context.el.id}`, () => {
              console.log(
               "handling switch_projection_map",
                this_map_context.map_instance.getProjection(),
                this_map_context.map_instance.getProjection()?.type,
                (this_map_context.map_instance.getProjection()?.type === 'globe' ? 'mercator' : 'globe')
              );
              if (this_map_context.map_instance.getProjection()?.type === 'globe') {
                this_map_context.map_instance.setProjection({
                  type: 'mercator'
                })
              } else {
                this_map_context.map_instance.setProjection({
                  type: 'globe'
                })
                this_map_context.map_instance.setSky({
                  'atmosphere-blend': [
                    'interpolate',
                    ['linear'],
                    ['zoom'],
                    0, 1,
                    5, 1,
                    7, 0
                  ]
                })
    
                // Apply light settings
                this_map_context.map_instance.setLight({
                  'anchor': 'map',
                  'position': [1.5, 90, 80]
                });
              }
            });

            this_map_context.handleEvent("spin_maps", () => {
              spin_maps();
            });

          }, 

          updated() {
            const this_map_context = this;
            all_maps.delete(this_map_context.map_instance);
    
            // Convert Set to Array before syncing
            if (all_maps.size > 1) {
              synchrornize_maps(Array.from(all_maps));
            }
    
            console.log("one map container dom updated");
          },
          destroyed() {
            const this_map_context = this;
            all_maps.delete(this_map_context.map_instance);
          },
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
      width: 100%;
      overflow: hidden;
    ">
      <div style="
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        padding: 10px;
        background-color: #f8f8f8;
        border-bottom: 1px solid #ddd;
        min-height: 60px;
        z-index: 10;
      ">
        <%= for style_key <- @style_keys do %>
          <button 
            phx-click="toggle_map"
            phx-value-style_key={style_key}
            style={if style_key in @active_style_keys, 
              do: "font-size: 1em; padding: 8px 16px; background-color: #4CAF50; color: white; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; transition: background-color 0.3s;", 
              else: "font-size: 1em; padding: 8px 16px; background-color: #f0f0f0; color: black; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; transition: background-color 0.3s;"
            }>
            <%= style_key %>
          </button>
        <% end %>
        <button
          phx-click="spin_maps"
          style="font-size: 1em; padding: 8px 16px; background-color: #007bff; color: white; border: 1px solid #0056b3; border-radius: 4px; cursor: pointer;"
        >
          🌍 Spin Maps
        </button>
      </div>
      
      <%= if @active_style_keys != MapSet.new([]) do %>
        <div style="
          display: flex;
          flex: 1;
          width: 100%;
          overflow: hidden;
          position: relative;
        ">
          <%= for style_key <- @active_style_keys do %>
            <div 
              id={style_key}
              phx-hook="one_map"
              phx-update="ignore"
              style="
                flex: 1;
                height: 100%;
              "
            />
            <button 
              phx-click="switch_projection_button"
              phx-value-style_key={style_key}
            >
              globe
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_map", %{"style_key" => style_key}, socket) do
    IO.puts """
      handling toggle map #{style_key}
    """
    active_stle_keys = 
      case style_key in socket.assigns.active_style_keys do
        false -> MapSet.put(socket.assigns.active_style_keys, style_key)
        true -> MapSet.delete(socket.assigns.active_style_keys, style_key)
      end
    socket = assign(
      socket, 
      active_style_keys: active_stle_keys
    )
    {:noreply, socket}
  end

  def handle_event("map_instance_loaded", %{"container_id" => container_id_and_also_style_key}, socket) do
    IO.puts """
      handling map loaded #{container_id_and_also_style_key}
    """
  
    socket = push_event(
      socket, 
      "update_map_#{container_id_and_also_style_key}", 
      %{"style" => styles()[container_id_and_also_style_key]}
    )
  
    {:noreply, socket}
  end

  def handle_event("switch_projection_button", %{"style_key" => style_key}, socket) do
    IO.puts """
      handling map switch projection button #{style_key}
    """
  
    socket = push_event(
      socket, 
      "switch_projection_map_#{style_key}", 
      %{}
    )
  
    {:noreply, socket}
  end

  def handle_event("spin_maps", _params, socket) do
    socket = push_event(socket, "spin_maps", %{})
    {:noreply, socket}
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
