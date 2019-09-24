// GoldBlockNBZ.as
// BW objective blob with a big no build zone
// required for the supply drop
#include "BW_Common.as"; //for rules stuff
#include "Hitters.as";
#include "DummyCommon.as";
#include "MapFlags.as";

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);

	this.Tag("place norotate");
	this.Tag("builder always hit");

	//block knight sword
	this.Tag("blocks sword");
	this.Tag("blocks water");

	if (getNet().isServer())
	{
        CMap@ map = getMap();
        if(map !is null) map.server_AddSector(this.getPosition(), 36, "no build");
        string propname = GOLD_PILE_COUNT_PREFIX + this.getTeamNum();
        getRules().set_Vec2f(GOLD_PILE_POS_PREFIX + this.getTeamNum(), this.getPosition());
		u8 goldcount = getRules().get_u8(propname);
		getRules().set_u8(propname, goldcount+1);
	}
	this.set_TileType("background tile", CMap::tile_castle_back);
	this.set_TileType(Dummy::TILE, Dummy::OBSTRUCTOR);

	MakeDamageFrame(this);
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
}

void onDie(CBlob@ this)
{
	if (getNet().isServer())
	{
        string propname = GOLD_PILE_COUNT_PREFIX + this.getTeamNum();
		u8 goldcount = getRules().get_u8(propname);
		getRules().set_u8(propname, goldcount-1);
	}
	this.getSprite().PlaySound("destroy_gold");
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	MakeDamageFrame(this);
}

void MakeDamageFrame(CBlob@ this)
{
	f32 hp = this.getHealth();
	f32 full_hp = this.getInitialHealth();
	int frame=( (hp > full_hp * 0.9f) ? 0 :
				(hp > full_hp * 0.7f) ? 1 :
				(hp > full_hp * 0.5f) ? 2 :
				(hp > full_hp * 0.3f) ? 3 : 4 );
	this.getSprite().animation.frame = frame;
}


bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	if(this.getName() == blob.getName() || blob.getName() == "gold_platform")
	{
		return false;
	}
	else
	{
		return true;
	}
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob !is this)
	{
		this.getSprite().PlaySound("dig_stone", Maths::Min(1.25f, Maths::Max(0.5f, damage)));
	}
	dictionary harvest;
	if (this.getTeamNum() == hitterBlob.getTeamNum()) //i'm bad, dont judge me
	{
		harvest.set('mat_gold', 0);
		this.set('harvest', harvest);
		return 0;
	}
	else
	{
		harvest.set('mat_gold', 4);
		this.set('harvest', harvest);
	}

	if (customData == Hitters::boulder)
		return 0;

	//print("custom data: "+customData+" builder: "+Hitters::builder);
	if (customData == Hitters::builder)
		damage *= 0.5f;
	if (customData == Hitters::builderaxe)
	{
		harvest.set('mat_gold', 0);
		this.set('harvest', harvest);
		damage *= 0.0f;
	}
	if (customData == Hitters::saw)                //Hitters::saw is the drill hitter.... why
		damage *= 2;
	if (customData == Hitters::bomb)
		damage *= 1.3f;

	return damage;
}
