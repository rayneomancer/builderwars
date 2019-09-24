// TDM PNG loader base class - extend this to add your own PNG loading functionality!

#include "BasePNGLoader.as";
#include "MinimapHook.as";
#include "BW_Common.as";

// TDM custom map colors
namespace bw_colors
{
	enum color
	{
		goldblock_blue = 0xFF8888FF, //additional gold blocks
		goldblock_blue_main = 0xFF885DFF, //no build zone and supply drop location
		goldblock_red =  0xFFFF8888, //additional gold blocks
		goldblock_red_main = 0xFFC66B6B //no build zone and supply drop location
	};
}

//the loader

class BWPNGLoader : PNGLoader
{
	BWPNGLoader()
	{
		super();
	}

	//override this to extend functionality per-pixel.
	void handlePixel(const SColor &in pixel, int offset) override
	{
		PNGLoader::handlePixel(pixel, offset);

		switch (pixel.color)
		{
		case bw_colors::goldblock_blue: 
			autotile(offset); 
			spawnBlob(map, "gold_platform", offset, 0); 
			break;
		case bw_colors::goldblock_blue_main: 
			autotile(offset); 
			spawnBlob(map, "gold_platform", offset, 0); 
			if(getMap() !is null) {getMap().server_AddSector(getSpawnPosition(map, offset), 36, "no build"); }
			getRules().set_Vec2f(GOLD_PILE_POS_PREFIX + 0, getSpawnPosition(map, offset));
			break;
		case bw_colors::goldblock_red: 
			autotile(offset); 
			spawnBlob(map, "gold_platform", offset, 1); 
			break;
		case bw_colors::goldblock_red_main: 
			autotile(offset); 
			spawnBlob(map, "gold_platform", offset, 1); 
			if(getMap() !is null) {getMap().server_AddSector(getSpawnPosition(map, offset), 36, "no build"); }
			getRules().set_Vec2f(GOLD_PILE_POS_PREFIX + 1, getSpawnPosition(map, offset));
			break;
		};
	}
};

// --------------------------------------------------

bool LoadMap(CMap@ map, const string& in fileName)
{
	print("LOADING TDM PNG MAP " + fileName);

	BWPNGLoader loader();

	MiniMap::Initialise();

	return loader.loadMap(map , fileName);
}
