// GenericFlame.as

#include "Hitters.as";

namespace Flame
{

	enum state
	{
		flame_off = 0,
		flame_on,
		falling
	};
}


// Todo: collision normal
void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if(!getNet().isServer() || this.get_u8("state") == Flame::flame_off || blob is null || !blob.getShape().getConsts().isFlammable || !blob.hasTag("flesh") || blob.hasTag("invincible") || this.get_bool("wet") ) return;

	this.server_Hit(blob, blob.getPosition(), blob.getVelocity() * -1, 0.5f, Hitters::fire, true);
}

bool canBePickedUp( CBlob@ this, CBlob@ byBlob )
{
	return false;
}