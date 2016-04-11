require 'json'

# Version History
# 2: export full visualization. Limitations: doesn't support Odyssey, export will fail if
#    any of parent_id / prev_id / next_id / slide_transition_options are set.
module Carto
  # Both String and Hash versions are provided because `deep_symbolize_keys` won't symbolize through arrays
  # and having separated methods make handling and testing much easier.
  class VisualizationsExportService2
    def build_visualization_from_json_export(exported_json_string)
      build_visualization_from_hash_export(JSON.parse(exported_json_string).deep_symbolize_keys)
    end

    def build_visualization_from_hash_export(exported_hash)
      raise "Wrong export version" unless compatible_version?(exported_hash[:version])

      build_visualization_from_hash(exported_hash[:visualization])
    end

    def export_visualization_json_string(visualization_id)
      export_visualization_json_hash(visualization_id).to_json
    end

    def export_visualization_json_hash(visualization_id)
      {
        version: CURRENT_VERSION,
        visualization: export_visualization(Carto::Visualization.find(visualization_id))
      }
    end

    private

    CURRENT_VERSION = '2.0.0'

    def compatible_version?(version)
      version.to_i == 2
    end

    def build_visualization_from_hash(exported_visualization)
      visualization = Carto::Visualization.new(
        name: exported_visualization[:name],
        description: exported_visualization[:description],
        type: exported_visualization[:type],
        tags: exported_visualization[:tags],
        privacy: exported_visualization[:privacy],
        url_options: exported_visualization[:url_options],
        source: exported_visualization[:source],
        license: exported_visualization[:license],
        title: exported_visualization[:title],
        kind: exported_visualization[:kind],
        attributions: exported_visualization[:attributions],
        bbox: exported_visualization[:bbox],
        display_name: exported_visualization[:display_name],
        map: build_map_from_hash(
          exported_visualization[:map],
          layers: build_layers_from_hash(exported_visualization[:layers])),
        analyses: exported_visualization[:analyses].map { |a| build_analysis_from_hash(a.deep_symbolize_keys) }
      )

      active_layer_order = exported_visualization[:layers].index { |l| l['active_layer'] }
      if active_layer_order
        visualization.active_layer = visualization.layers.find { |l| l.order == active_layer_order }
      end

      visualization
    end

    def build_map_from_hash(exported_map, layers:)
      Carto::Map.new(
        provider: exported_map[:provider],
        bounding_box_sw: exported_map[:bounding_box_sw],
        bounding_box_ne: exported_map[:bounding_box_ne],
        center: exported_map[:center],
        zoom: exported_map[:zoom],
        view_bounds_sw: exported_map[:view_bounds_sw],
        view_bounds_ne: exported_map[:view_bounds_ne],
        scrollwheel: exported_map[:scrollwheel],
        legends: exported_map[:legends],
        layers: layers
      )
    end

    def build_layers_from_hash(exported_layers)
      return [] unless exported_layers

      exported_layers.map.with_index.map { |layer, i| build_layer_from_hash(layer.deep_symbolize_keys, order: i) }
    end

    def build_layer_from_hash(exported_layer, order:)
      layer = Carto::Layer.new(
        options: exported_layer[:options],
        kind: exported_layer[:kind],
        infowindow: exported_layer[:infowindow],
        order: order,
        tooltip: exported_layer[:tooltip]
      )
      layer.widgets = build_widgets_from_hash(exported_layer[:widgets], layer: layer)
      layer
    end

    def build_analysis_from_hash(exported_analysis)
      return nil unless exported_analysis

      Carto::Analysis.new(analysis_definition_json: exported_analysis[:analysis_definition])
    end

    def build_widgets_from_hash(exported_widgets, layer:)
      return [] unless exported_widgets

      exported_widgets.map.with_index.map { |w, i| build_widget_from_hash(w.deep_symbolize_keys, order: i, layer: layer) }
    end

    def build_widget_from_hash(exported_widget, order:, layer:)
      return nil unless exported_widget

      Carto::Widget.new(
        order: order,
        layer: layer,
        type: exported_widget[:type],
        title: exported_widget[:title],
        options_json: exported_widget[:options]
      )
    end

    def export_visualization(visualization)
      {
        name: visualization.name,
        description: visualization.description,
        type: visualization.type,
        tags: visualization.tags,
        privacy: visualization.privacy,
        url_options: visualization.url_options,
        source: visualization.source,
        license: visualization.license,
        title: visualization.title,
        kind: visualization.kind,
        attributions: visualization.attributions,
        bbox: visualization.bbox,
        display_name: visualization.display_name,
        map: export_map(visualization.map),
        layers: visualization.layers.map { |l| export_layer(l, active_layer: visualization.active_layer_id == l.id) }
      }
    end

    def export_map(map)
      {
        provider: map.provider,
        bounding_box_sw: map.bounding_box_sw,
        bounding_box_ne: map.bounding_box_ne,
        center: map.center,
        zoom: map.zoom,
        view_bounds_sw: map.view_bounds_sw,
        view_bounds_ne: map.view_bounds_ne,
        scrollwheel: map.scrollwheel,
        legends: map.legends
      }
    end

    def export_layer(layer, active_layer: false)
      layer = {
        options: layer.options,
        kind: layer.kind,
        infowindow: layer.infowindow,
        tooltip: layer.tooltip,
        widgets: layer.widgets.map { |w| export_widget(w) }
      }

      layer[:active_layer] = true if active_layer

      layer
    end

    def export_widget(widget)
      {
        options: widget.options_json,
        type: widget.type,
        title: widget.title
      }
    end
  end
end
