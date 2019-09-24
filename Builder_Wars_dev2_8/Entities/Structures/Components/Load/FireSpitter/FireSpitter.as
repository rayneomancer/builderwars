// FireSpitter.as
// 9/16/2018 ~r

#include "MechanismsCommon.as";
#include "DummyCommon.as";
#include "Hitters.as";

class FireSpitter : Component
{
	u16 id;
	Vec2f offset;

	FireSpitter(Vec2f position, u16 netID, Vec2f _offset)
	{
		x = position.x;
		y = position.y;

		id = netID;
		offset = _offset;
	}

	void Activate(CBlob@ this)
	{
		Vec2f position = this.getPosition();

		CMap@ map = getMap();
		if(map.rayCastSolid(position + offset * 5, position + offset * 11))
		{
			this.getSprite().PlaySound("dry_hit.ogg");
			return;
		}

		AttachmentPoint@ mechanism = this.getAttachments().getAttachmentPointByName("MECHANISM");
		if(mechanism is null) return;

		mechanism.offset = Vec2f(0, -7);

		CBlob@ flame = mechanism.getOccupied();
		if(flame is null) return;
		if(flame.get_bool("wet")) return;

		flame.set_u8("state", 1);

		// hit flesh at target position
		if(getNet().isServer())
		{
			CBlob@[] blobs;
			map.getBlobsAtPosition(offset * 8 + position, @blobs);
			for(uint i = 0; i < blobs.length; i++)
			{
				CBlob@ blob = blobs[i];
				if(!blob.hasTag("flesh")) continue;

				flame.server_Hit(blob, blob.getPosition(), blob.getVelocity() * -1, 1.0f, Hitters::fire, true);
			}
		}

		CSprite@ sprite = this.getSprite();
		if(sprite is null) return;

		sprite.SetEmitSound("CampfireSound.ogg");
		sprite.SetEmitSoundPaused(false);
	}

	void Deactivate(CBlob@ this)
	{
		// if ! blocked, do stuff

		AttachmentPoint@ mechanism = this.getAttachments().getAttachmentPointByName("MECHANISM");
		if(mechanism is null) return;

		mechanism.offset = Vec2f(0, 0);

		CBlob@ flame = mechanism.getOccupied();
		if(flame is null) return;

		flame.set_u8("state", 0);

		CSprite@ sprite = this.getSprite();
		if(sprite is null) return;

		sprite.SetEmitSoundPaused(true);
	}
}

void onInit(CBlob@ this)
{
	// used by BuilderHittable.as
	this.Tag("builder always hit");

	// used by KnightLogic.as
	this.Tag("blocks sword");

	// used by TileBackground.as
	this.set_TileType("background tile", CMap::tile_castle_back);
	this.set_TileType(Dummy::TILE, Dummy::OBSTRUCTOR);

}

void onTick(CBlob@ this)
{
	const u32 gametime = getGameTime();
	CMap@ map = getMap();
	const u16 angle = this.getAngleDegrees();
	const Vec2f offset1 = Vec2f(0, -8).RotateBy(angle);
	const Vec2f offset2 = Vec2f(0, -16).RotateBy(angle);
	AttachmentPoint@ mechanism = this.getAttachments().getAttachmentPointByName("MECHANISM");
		if(mechanism is null) return;
	CBlob@ flame = mechanism.getOccupied();
		if(flame is null) return;

	if(flame.get_bool("wet"))
	{
		this.getSprite().SetEmitSoundPaused(true);
	}
	else if(flame.get_u8("state") == 1)
	{
		this.getSprite().SetEmitSoundPaused(false);

		if(getNet().isServer() && (gametime % 30 == 0))
		{
			CBlob@[] blobs;
			map.getBlobsAtPosition(this.getPosition() + offset1, @blobs);
			for(uint i = 0; i < blobs.length; i++)
			{
				CBlob@ blob = blobs[i];
				if(blob.hasTag("flesh") || blob.hasTag("wooden")) 
				{
					flame.server_Hit(blob, blob.getPosition(), blob.getVelocity() * -1, 1.0f, Hitters::fire, true);
				}
			}
			map.server_setFireWorldspace(this.getPosition() + offset1, true);
			map.server_setFireWorldspace(this.getPosition() + offset2, true);
		}
	}
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if(!isStatic || this.exists("component")) return;

	const Vec2f position = this.getPosition() / 8;
	const u16 angle = this.getAngleDegrees();
	const Vec2f offset = Vec2f(0, -1).RotateBy(angle);

	FireSpitter component(position, this.getNetworkID(), offset);
	this.set("component", component);

	this.getAttachments().getAttachmentPointByName("MECHANISM").offsetZ = -5;

	if(getNet().isServer())
	{
		MapPowerGrid@ grid;
		if(!getRules().get("power grid", @grid)) return;

		grid.setAll(
		component.x,                        // x
		component.y,                        // y
		TOPO_CARDINAL,                      // input topology
		TOPO_NONE,                          // output topology
		INFO_LOAD,                          // information
		0,                                  // power
		component.id);                      // id

		CBlob@ flame = server_CreateBlob("flame", this.getTeamNum(), this.getPosition());
		flame.setAngleDegrees(this.getAngleDegrees());
		flame.set_u8("state", 0);

		ShapeConsts@ consts = flame.getShape().getConsts();
		consts.mapCollisions = false;
		consts.collideWhenAttached = true;

		this.server_AttachTo(flame, "MECHANISM");
	}

	CSprite@ sprite = this.getSprite();
	if(sprite is null) return;

	sprite.SetZ(500);
	sprite.SetFrameIndex(angle / 90);
	sprite.SetFacingLeft(false);

	/*CSpriteLayer@ layer = sprite.addSpriteLayer("background", "Spiker.png", 8, 16);
	layer.addAnimation("default", 0, false);
	layer.animation.AddFrame(4);
	layer.SetRelativeZ(-10);
	layer.SetFacingLeft(false);*/
}

void onDie(CBlob@ this)
{
	if(!getNet().isServer()) return;

	CBlob@ flame = this.getAttachments().getAttachmentPointByName("MECHANISM").getOccupied();
	if(flame is null) return;

	flame.server_Die();
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	AttachmentPoint@ mechanism = this.getAttachments().getAttachmentPointByName("MECHANISM");
		if(mechanism is null) return 0;
	CBlob@ flame = mechanism.getOccupied();
		if(flame is null) return 0;
	if (customData == Hitters::water)
	{
		flame.set_bool("wet", true);
		flame.set_u8("wettimer", 0);
		return 0;
	}

	return damage;
}