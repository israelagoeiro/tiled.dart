part of tiled;

class Layer {
  static const int FLIPPED_HORIZONTALLY_FLAG = 0x80000000;
  static const int FLIPPED_VERTICALLY_FLAG = 0x40000000;
  static const int FLIPPED_DIAGONALLY_FLAG = 0x20000000;

  String name;
  int width;
  int height;
  bool visible;

  Map<String, dynamic> properties = {};

  TileMap map;
  List<List<int>> tileMatrix;

  List<List<Tile>> _tiles;
  List<List<Tile>> get tiles {
    if (_tiles == null) {
      _recalculateTiles();
    }
    return _tiles;
  }

  Layer(this.name, this.width, this.height);

  Layer.fromXML(XmlElement element) {
    if (element == null) {
      throw 'arg "element" cannot be null';
    }

    NodeDSL.on(element, (dsl) {
      name = dsl.strOr('name', name);
      width = dsl.intOr('width', width);
      height = dsl.intOr('height', height);
      visible = dsl.boolOr('visible', true);
    });

    var dataElement = element.children.firstWhere(
        (node) => node is XmlElement && node.name.local == 'data',
        orElse: () => null);
    if (dataElement is XmlElement) {
      var decoder =
          TileMapParser._getDecoder(dataElement.getAttribute('encoding'));
      var decompressor = TileMapParser._getDecompressor(
          dataElement.getAttribute('compression'));

      var decodedString = decoder(dataElement.text);
      var inflatedString = decompressor?.call(decodedString) ?? decodedString;

      assembleTileMatrix(inflatedString);
    }

    properties = TileMapParser._parsePropertiesFromElement(element);
  }

  // TMX data format documented here: https://github.com/bjorn/tiled/wiki/TMX-Map-Format#data
  assembleTileMatrix(var bytes) {
    tileMatrix = new List<List<int>>(height);

    var tileIndex = 0;
    for (var y = 0; y < height; ++y) {
      tileMatrix[y] = new List<int>(width);
      for (var x = 0; x < width; ++x) {
        var globalTileId = bytes[tileIndex] |
            bytes[tileIndex + 1] << 8 |
            bytes[tileIndex + 2] << 16 |
            bytes[tileIndex + 3] << 24;

        tileIndex += 4;

        // Read out the flags
        var flipped_horizontally = (globalTileId & FLIPPED_HORIZONTALLY_FLAG);
        var flipped_vertically = (globalTileId & FLIPPED_VERTICALLY_FLAG);
        var flipped_diagonally = (globalTileId & FLIPPED_DIAGONALLY_FLAG);

        // Clear the flags

        globalTileId &= ~(FLIPPED_HORIZONTALLY_FLAG |
            FLIPPED_VERTICALLY_FLAG |
            FLIPPED_DIAGONALLY_FLAG);

        tileMatrix[y][x] = globalTileId;
      }
    }
  }

  _recalculateTiles() {
    var px = 0;
    var py = 0;
    var tileId;
    var tile;
    _tiles = new List<List<Tile>>(width);
   
    _tiles.asMap().forEach( (i,e){
      _tiles[i] = new List(height);
    } );

    _tiles.asMap().forEach((i, List<Tile> cols) {
      px = 0;
      
      cols.asMap().forEach((j, Tile t) {
        tileId = tileMatrix[j][i];
        tile = map.getTileByGID(tileId)
        ..x = i
        ..y = j
        ..px = px
        ..py = py;
      
        _tiles[i][j] = tile;
        px += map.tileWidth;
      });
    
      py += map.tileHeight;
    });
  }
}
