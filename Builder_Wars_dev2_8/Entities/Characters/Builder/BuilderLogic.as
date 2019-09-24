// Builder logic
// axe added 9-4-2018 ~r

#include "Hitters.as";
#include "Knocked.as";
#include "BuilderCommon.as";
#include "ThrowCommon.as";
#include "RunnerCommon.as";
#include "Help.as";
#include "Requirements.as"
#include "BuilderHittable.as";
#include "PlacementCommon.as";
#include "ParticleSparks.as";
#include "MaterialCommon.as";

//can't be <2 - needs one frame less for gathering infos
const s32 hit_frame = 2;
const f32 hit_damage = 0.5f;
const u8 axe_time = 12; //change axestrike animation speed before messing with this, its to sync the delay after swing
bool tilehits = false;

//attacks limited to the one time per-actor before reset.

void builder_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
	this.Sync("LimitedActors", true);
}

bool builder_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 builder_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void builder_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
	this.Sync("LimitedActors", true);
}

void builder_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
	this.Sync("LimitedActors", true);
}

void Axe(CBlob@ this, f32 damage, u8 type) //axe for mass wood destruction/harvesting
{
    if (!getNet().isServer()) {
        return;
    }
    f32 aimangle = 180;//(this.isFacingLeft() ? 180 : 0 );
    Vec2f blobPos = this.getPosition();
    Vec2f pos;
    if (this.isFacingLeft())
    {
    	pos = blobPos - Vec2f(4,0).RotateBy(aimangle);
    } 
    else
    {
    	pos = blobPos - Vec2f(-4,0).RotateBy(aimangle);
    }
    f32 attack_distance = 19.0f;
    f32 radius = this.getRadius();
    CMap@ map = this.getMap();
    // this gathers HitInfo objects which contain blob or tile hit information
    HitInfo@[] hitInfos;
    f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();
    Vec2f vel = this.getVelocity();
    Vec2f slash_direction;
    Vec2f aiming_direction = vel;
	aiming_direction.x *= 2;
	aiming_direction.Normalize();
	slash_direction = aiming_direction;
    Vec2f slash_vel =  slash_direction * this.getMass() * 0.4f;
	//this.AddForce(slash_vel);

	bool dontHitMore = false;
	bool dontHitMoreMap = this.get_bool("dontHitMoreMap");
	if (map.getHitInfosFromArc( pos , -exact_aimangle, 70.0f, radius + attack_distance + aiming_direction.Normalize(), this, @hitInfos) )
    {
		//HitInfo objects are sorted, first come closest hits
        for (uint i = 0; i < hitInfos.length; i++)
        {
			HitInfo@ hi = hitInfos[i];
			bool wood = map.isTileWood(hi.tile);
			CBlob@ b = hi.blob;

            if (b !is null && !dontHitMore) // hit blobs, not tiles
			{
				const bool large = b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();
				if (b.getTeamNum() == this.getTeamNum() && !b.hasTag("dead")) { // no TK
					continue;
				}

				if (b.hasTag("stone")) { // can't break stone doors
					break;
				}
				if (builder_has_hit_actor(this, b))
				{
					continue;
				}
				if (large)
				{
					dontHitMore = true;
				}

				builder_add_actor_limit(this, b);
				
				Vec2f velocity = b.getPosition() - pos;
				this.server_Hit( b, hi.hitpos, velocity, damage, type, true); // server_Hit() is server-side only
				if (b.getName() == "log")
				{
					CBlob@ ore = server_CreateBlobNoInit("mat_wood");
					if (ore !is null)
					{
						ore.Tag('custom quantity');
						ore.Init();
						ore.setPosition(pos);
						ore.server_SetQuantity(12);
					}
				}

			}
			else if (wood && !dontHitMoreMap) //only hit tilemap if it's wooden
			{
				Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
				Vec2f offset = (tpos - blobPos);
				f32 tileangle = offset.Angle();
				f32 dif = Maths::Abs(exact_aimangle - tileangle);
				if (dif > 180)
					dif -= 360;
				if (dif < -180)
					dif += 360;

				dif = Maths::Abs(dif);

				if (dif < 40.0f)
				{
					//detect corner

					int check_x = -(offset.x > 0 ? -1 : 1);
					int check_y = -(offset.y > 0 ? -1 : 1);
					if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
					        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
						continue;

					bool canhit = true; //default true if not no build zone

					//dont dig through no build zones
					canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;
					
					if (canhit && tilehits)
					{
						//map.server_DestroyTile(hi.hitpos, 0.1f, this);
						map.server_DestroyTile(hi.hitpos, 0.1f, this); //bad code :shrug:
					}
				}
			}
		}
	}
}

void onInit(CBlob@ this)
{
	this.set_f32("pickaxe_distance", 10.0f);
	this.set_f32("gib health", -1.5f);

	this.Tag("player");
	this.Tag("flesh");
	this.set_string("tool", "pickaxe"); //set default tool on spawn
	this.set_u8("axetimer", 0);
	this.set_u8("tprop",0); //attack state timer
	this.set_bool("swinging", false);
	this.set_bool("true_hit", false);
	this.set_bool("dontHitMoreMap", false);

	HitData hitdata;
	this.set("hitdata", hitdata);
	builder_actorlimit_setup(this);

	this.addCommandID("pickaxe");
	this.addCommandID("axe");

	CShape@ shape = this.getShape();
	shape.SetRotationsAllowed(false);
	shape.getConsts().net_threshold_multiplier = 0.5f;

	this.set_Vec2f("inventory offset", Vec2f(0.0f, 160.0f));

	SetHelp(this, "help self action2", "builder", getTranslatedString("$Pick$Dig/Chop  $KEY_HOLD$$RMB$"), "", 3);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if(player !is null)
	{
		player.SetScoreboardVars("ScoreboardIcons.png", 1, Vec2f(16, 16));
	}
}

void onTick(CBlob@ this)
{
	if(this.isInInventory())
		return;

	AttachmentPoint@ hands = this.getAttachments().getAttachmentPointByName("PICKUP");
	if(hands is null) return;
	CBlob@ held = hands.getOccupied();

	const bool ismyplayer = this.isMyPlayer();
	const string tool = this.get_string("tool");
	u8 axetimer = this.get_u8("axetimer");
	u8 dummytimer = this.get_u8("dummytimer"); //after swing delay
	bool swinging = this.get_bool("swinging");

	if(ismyplayer && getHUD().hasMenus())
	{
		if(swinging) //kill state
		{
			swinging = false;
			this.set_bool("swinging", swinging);
		}
		return;
	}

	// actions
	//TODO: make handy tool function instead of having it all onTick
	if(isKnocked(this))
	{
		this.set_u8("dummytimer", axe_time);
		this.set_bool("dontHitMoreMap", false);
		this.Sync("dontHitMoreMap", true);
	}
	if(tool == "pickaxe")
	{
		if(ismyplayer)
		{
			Pickaxe(this);
		}
	}
	else if (tool == "axe") //sorry
	{
		bool busy;
		if( held !is null && ((held.getName() == "drill") || (held.getName() == "boulder")))
		{	
			busy = true;
			if(swinging)
			{
				swinging = false;
				this.set_bool("swinging", swinging);
			}
			if (this.isKeyJustPressed(key_action2))
			{
				Sound::Play("NoAmmo.ogg");
			}	
			//return; //no bullying >:^(
		}
		else
		{
			busy = false;
		}

		if (this.isKeyPressed(key_action2) && !this.hasTag("axehit") /*dummytimer == axe_time*/ && !busy)//hold to charge
		{
			this.set_bool("swinging", true);
			this.Sync("swinging", true);
		}

		if (swinging) //fake state for swinging
		{
			axetimer++;
			this.set_u8("axetimer", axetimer);
		}
		else
		{
			axetimer = 0;
			this.set_u8("axetimer", axetimer);
		}

		if(axetimer >= 15 && this.isKeyJustReleased(key_action2))//release to swing
		{
			this.Tag("axehit");
			this.Sync("axehit", true);
			swinging = false;
			this.set_bool("swinging", swinging);
			this.getSprite().PlayRandomSound("SwordSlash", 3.0f);
			this.set_u8("dummytimer", 0);
		}
		else if(axetimer <= 15 && this.isKeyJustReleased(key_action2))//released too soon, reset without hitting
		{
			swinging = false;
			this.set_bool("swinging", swinging);
		}
		else if(axetimer >= 55)
		{
			SetKnocked(this, 30, true);
			this.getSprite().PlaySound("/Stun", 2.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
		}

		if (this.hasTag("axehit"))//fake slashing state
		{
			int t = this.get_u8("tprop");
			if(!isKnocked(this))
			{
				//CBitStream params;
				t++;
				this.set_u8("tprop",t);
				if(t > axe_time)
				{
					this.set_u8("tprop",0);
					this.Untag("axehit");
					this.Sync("axehit", true);
					builder_clear_actor_limits(this);
					this.set_bool("dontHitMoreMap", false);
					this.Sync("dontHitMoreMap", true);
				}
				else if(t < 6) //hit over multiple ticks 
				{
					//this.SendCommand(this.getCommandID("axe"), params);
					Axe(this, 1.0f, Hitters::builderaxe);
					if(t > 2)
					{
						tilehits = false;
					}
					else
					{
						tilehits = true;
					}
				}
				else if(t == 2)
				{
					this.set_bool("dontHitMoreMap", true);
					this.Sync("dontHitMoreMap", true);
				}
				
			}
			else
			{
				this.Untag("axehit");
				this.Sync("axehit", true);
				builder_clear_actor_limits(this);
				this.set_bool("dontHitMoreMap", false);
				this.Sync("dontHitMoreMap", true);
				this.set_u8("dummytimer", axe_time);
			}
		}
	}
	if(this.isKeyJustPressed(key_action3))
	{
		CBlob@ carried = this.getCarriedBlob();
		if(carried is null || !carried.hasTag("temp blob"))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}

	// slow down walking
	if((this.isKeyPressed(key_action2) && (this.get_string("tool") == "pickaxe")) /*|| swinging*/)
	{
		RunnerMoveVars@ moveVars;
		if(this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor = 0.5f;
			moveVars.jumpFactor = 0.5f;
		}
	}

	if(ismyplayer && this.isKeyPressed(key_action1) && !this.isKeyPressed(key_inventory)) //Don't let the builder place blocks if he/she is selecting which one to place
	{
		if (swinging) return;
		BlockCursor @bc;
		this.get("blockCursor", @bc);

		HitData@ hitdata;
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = bc.buildable ? bc.tileAimPos : Vec2f(-8, -8);
	}

	// get rid of the built item
	if(this.isKeyJustPressed(key_inventory) || this.isKeyJustPressed(key_pickup))
	{
		this.set_u8("buildblob", 255);
		this.set_TileType("buildtile", 0);

		CBlob@ blob = this.getCarriedBlob();
		if(blob !is null && blob.hasTag("temp blob"))
		{
			blob.Untag("temp blob");
			blob.server_Die();
		}
	}
}

void SendHitCommand(CBlob@ this, CBlob@ blob, const Vec2f tilepos, const Vec2f attackVel, const f32 attack_power)
{
	CBitStream params;
	params.write_netid(blob is null? 0 : blob.getNetworkID());
	params.write_Vec2f(tilepos);
	params.write_Vec2f(attackVel);
	params.write_f32(attack_power);

	this.SendCommand(this.getCommandID("pickaxe"), params);
}

bool RecdHitCommand(CBlob@ this, CBitStream@ params)
{
	u16 blobID;
	Vec2f tilepos, attackVel;
	f32 attack_power;

	if(!params.saferead_netid(blobID))
		return false;
	if(!params.saferead_Vec2f(tilepos))
		return false;
	if(!params.saferead_Vec2f(attackVel))
		return false;
	if(!params.saferead_f32(attack_power))
		return false;

	if(blobID == 0)
	{
		CMap@ map = getMap();
		if(map !is null)
		{
			if(map.getSectorAtPosition(tilepos, "no build") is null)
			{
				uint16 type = map.getTile(tilepos).type;

				if (getNet().isServer())
				{
					map.server_DestroyTile(tilepos, 1.0f, this);

					Material::fromTile(this, type, 1.0f);
				}

				if (getNet().isClient())
				{
					if (map.isTileBedrock(type))
					{
						this.getSprite().PlaySound("/metal_stone.ogg");
						sparks(tilepos, attackVel.Angle(), 1.0f);
					}
				}
			}
		}
	}
	else
	{
		CBlob@ blob = getBlobByNetworkID(blobID);
		if(blob !is null)
		{
			bool isdead = blob.hasTag("dead");

			if(isdead) //double damage to corpses
			{
				attack_power *= 2.0f;
			}

			const bool teamHurt = !blob.hasTag("flesh") || isdead;

			if (getNet().isServer())
			{
				this.server_Hit(blob, tilepos, attackVel, attack_power, Hitters::builder, teamHurt);

				Material::fromBlob(this, blob, attack_power);
			}
		}
	}

	return true;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("pickaxe"))
	{
		if(!RecdHitCommand(this, params))
		{
			warn("error when recieving pickaxe command");
		}
	}
	else if (cmd == this.getCommandID("axe"))
	{
		//Axe(this, 1.0f, Hitters::builderaxe);
	}
}

//helper class to reduce function definition cancer
//and allow passing primitives &inout
class SortHitsParams
{
	Vec2f aimPos;
	Vec2f tilepos;
	Vec2f pos;
	bool justCheck;
	bool extra;
	bool hasHit;
	HitInfo@ bestinfo;
	f32 bestDistance;
};

void Pickaxe(CBlob@ this)
{
	HitData@ hitdata;
	CSprite @sprite = this.getSprite();
	bool strikeAnim = sprite.isAnimation("strike");

	if(!strikeAnim)
	{
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = Vec2f_zero;
		return;
	}

	// no damage cause we just check hit for cursor display
	bool justCheck = !sprite.isFrameIndex(hit_frame);
	bool adjusttime = sprite.getFrameIndex() < hit_frame - 1;

	// pickaxe!

	this.get("hitdata", @hitdata);

	if(hitdata is null) return;

	Vec2f blobPos = this.getPosition();
	Vec2f aimPos = this.getAimPos();
	Vec2f aimDir = aimPos - blobPos;

	// get tile surface for aiming at little static blobs
	Vec2f normal = aimDir;
	normal.Normalize();

	Vec2f attackVel = normal;

	if (!adjusttime)
	{
		if (!justCheck)
		{
			if (hitdata.blobID == 0)
			{
				SendHitCommand(this, null, hitdata.tilepos, attackVel, hit_damage);
			}
			else
			{
				CBlob@ b = getBlobByNetworkID(hitdata.blobID);
				if (b !is null)
				{
					SendHitCommand(this, b, (b.getPosition() + this.getPosition()) * 0.5f, attackVel, hit_damage);
				}
			}
		}
		return;
	}

	hitdata.blobID = 0;
	hitdata.tilepos = Vec2f_zero;

	f32 arcdegrees = 90.0f;

	f32 aimangle = aimDir.Angle();
	Vec2f pos = blobPos - Vec2f(2, 0).RotateBy(-aimangle);
	f32 attack_distance = this.getRadius() + this.get_f32("pickaxe_distance");
	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;

	bool hasHit = false;

	const f32 tile_attack_distance = attack_distance * 1.5f;
	Vec2f tilepos = blobPos + normal * Maths::Min(aimDir.Length() - 1, tile_attack_distance);
	Vec2f surfacepos;
	map.rayCastSolid(blobPos, tilepos, surfacepos);

	Vec2f surfaceoff = (tilepos - surfacepos);
	f32 surfacedist = surfaceoff.Normalize();
	tilepos = (surfacepos + (surfaceoff * (map.tilesize * 0.5f)));

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@ bestinfo = null;
	f32 bestDistance = 100000.0f;

	HitInfo@[] hitInfos;

	//setup params for ferrying data in/out
	SortHitsParams@ hit_p = SortHitsParams();

	//copy in
	hit_p.aimPos = aimPos;
	hit_p.tilepos = tilepos;
	hit_p.pos = pos;
	hit_p.justCheck = justCheck;
	hit_p.extra = true;
	hit_p.hasHit = hasHit;
	@(hit_p.bestinfo) = bestinfo;
	hit_p.bestDistance = bestDistance;

	if (map.getHitInfosFromArc(pos, -aimangle, arcdegrees, attack_distance, this, @hitInfos))
	{
		SortHits(this, hitInfos, hit_damage, hit_p);
	}

	aimPos = hit_p.aimPos;
	tilepos = hit_p.tilepos;
	pos = hit_p.pos;
	justCheck = hit_p.justCheck;
	hasHit = hit_p.hasHit;
	@bestinfo = hit_p.bestinfo;
	bestDistance = hit_p.bestDistance;

	bool noBuildZone = map.getSectorAtPosition(tilepos, "no build") !is null;
	bool isgrass = false;

	if ((tilepos - aimPos).Length() < bestDistance - 4.0f && map.getBlobAtPosition(tilepos) is null)
	{
		Tile tile = map.getTile(surfacepos);

		if (!noBuildZone && !map.isTileGroundBack(tile.type))
		{
			//normal, honest to god tile
			if (map.isTileBackgroundNonEmpty(tile) || map.isTileSolid(tile))
			{
				hasHit = true;
				hitdata.tilepos = tilepos;
			}
			else if (map.isTileGrass(tile.type))
			{
				//NOT hashit - check last for grass
				isgrass = true;
			}
		}
	}

	if (!hasHit)
	{
		//copy in
		hit_p.aimPos = aimPos;
		hit_p.tilepos = tilepos;
		hit_p.pos = pos;
		hit_p.justCheck = justCheck;
		hit_p.extra = false;
		hit_p.hasHit = hasHit;
		@(hit_p.bestinfo) = bestinfo;
		hit_p.bestDistance = bestDistance;

		//try to find another possible one
		if (bestinfo is null)
		{
			SortHits(this, hitInfos, hit_damage, hit_p);
		}

		//copy out
		aimPos = hit_p.aimPos;
		tilepos = hit_p.tilepos;
		pos = hit_p.pos;
		justCheck = hit_p.justCheck;
		hasHit = hit_p.hasHit;
		@bestinfo = hit_p.bestinfo;
		bestDistance = hit_p.bestDistance;

		//did we find one (or have one from before?)
		if (bestinfo !is null)
		{
			hitdata.blobID = bestinfo.blob.getNetworkID();
		}
	}

	if (isgrass && bestinfo is null)
	{
		hitdata.tilepos = tilepos;
	}
}

void SortHits(CBlob@ this, HitInfo@[]@ hitInfos, f32 damage, SortHitsParams@ p)
{
	//HitInfo objects are sorted, first come closest hits
	for (uint i = 0; i < hitInfos.length; i++)
	{
		HitInfo@ hi = hitInfos[i];

		CBlob@ b = hi.blob;
		if (b !is null) // blob
		{
			if (!canHit(this, b, p.tilepos, p.extra))
			{
				continue;
			}

			if (!p.justCheck && isUrgent(this, b))
			{
				p.hasHit = true;
				SendHitCommand(this, hi.blob, hi.hitpos, hi.blob.getPosition() - p.pos, damage);
			}
			else
			{
				bool never_ambig = neverHitAmbiguous(b);
				f32 len = never_ambig ? 1000.0f : (p.aimPos - b.getPosition()).Length();
				if (len < p.bestDistance)
				{
					if (!never_ambig)
						p.bestDistance = len;

					@(p.bestinfo) = hi;
				}
			}
		}
	}
}

bool ExtraQualifiers(CBlob@ this, CBlob@ b, Vec2f tpos)
{
	//urgent stuff gets a pass here
	if (isUrgent(this, b))
		return true;

	//check facing - can't hit stuff we're facing away from
	f32 dx = (this.getPosition().x - b.getPosition().x) * (this.isFacingLeft() ? 1 : -1);
	if (dx < 0)
		return false;

	//only hit static blobs if aiming directly at them
	CShape@ bshape = b.getShape();
	if (bshape.isStatic())
	{
		bool bigenough = bshape.getWidth() >= 8 &&
		                 bshape.getHeight() >= 8;

		if (bigenough)
		{
			if (!b.isPointInside(this.getAimPos()) && !b.isPointInside(tpos))
				return false;
		}
		else
		{
			Vec2f bpos = b.getPosition();
			//get centered on the tile it's positioned on (for offset blobs like spikes)
			Vec2f tileCenterPos = Vec2f(s32(bpos.x / 8), s32(bpos.y / 8)) * 8 + Vec2f(4, 4);
			f32 dist = Maths::Min((tileCenterPos - this.getAimPos()).LengthSquared(),
			                      (tileCenterPos - tpos).LengthSquared());
			if (dist > 25) //>5*5
				return false;
		}
	}

	return true;
}

bool neverHitAmbiguous(CBlob@ b)
{
	string name = b.getName();
	return name == "saw";
}

bool canHit(CBlob@ this, CBlob@ b, Vec2f tpos, bool extra = true)
{
	if(extra && !ExtraQualifiers(this, b, tpos))
	{
		return false;
	}

	if(b.hasTag("invincible"))
	{
		return false;
	}

	if(b.getTeamNum() == this.getTeamNum())
	{
		//no hitting friendly carried stuff
		if(b.isAttached())
			return false;

		//yes hitting corpses
		if(b.hasTag("dead"))
			return true;

		//no hitting friendly mines (grif)
		if(b.getName() == "mine")
			return false;

		//no hitting friendly living stuff
		if(b.hasTag("flesh") || b.hasTag("player"))
			return false;
	}
	//no hitting stuff in hands
	else if(b.isAttached() && !b.hasTag("player"))
	{
		return false;
	}

	//static/background stuff
	CShape@ b_shape = b.getShape();
	if(!b.isCollidable() || (b_shape !is null && b_shape.isStatic()))
	{
		//maybe we shouldn't hit this..
		//check if we should always hit
		if(BuilderAlwaysHit(b))
		{
			if(!b.isCollidable() && !isUrgent(this, b))
			{
				//TODO: use a better overlap check here
				//this causes issues with quarters and
				//any other case where you "stop overlapping"
				if(!this.isOverlapping(b))
					return false;
			}
			return true;
		}
		//otherwise no hit
		return false;
	}

	return true;
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	// ignore collision for built blob
	BuildBlock[][]@ blocks;
	if(!this.get("blocks", @blocks))
	{
		return;
	}

	const u8 PAGE = this.get_u8("build page");
	for(u8 i = 0; i < blocks[PAGE].length; i++)
	{
		BuildBlock@ block = blocks[PAGE][i];
		if(block !is null && block.name == detached.getName())
		{
			this.IgnoreCollisionWhileOverlapped(null);
			detached.IgnoreCollisionWhileOverlapped(null);
		}
	}

	// BUILD BLOB
	// take requirements from blob that is built and play sound
	// put out another one of the same
	if(detached.hasTag("temp blob"))
	{
		if(!detached.hasTag("temp blob placed"))
		{
			detached.server_Die();
			return;
		}

		uint i = this.get_u8("buildblob");
		if(i >= 0 && i < blocks[PAGE].length)
		{
			BuildBlock@ b = blocks[PAGE][i];
			if(b.name == detached.getName())
			{
				this.set_u8("buildblob", 255);
				this.set_TileType("buildtile", 0);

				CInventory@ inv = this.getInventory();

				CBitStream missing;
				if(hasRequirements(inv, b.reqs, missing, not b.buildOnGround))
				{
					server_TakeRequirements(inv, b.reqs);
				}
				// take out another one if in inventory
				server_BuildBlob(this, blocks[PAGE], i);
			}
		}
	}
	else if(detached.getName() == "seed")
	{
		if (not detached.hasTag('temp blob placed')) return;

		CBlob@ anotherBlob = this.getInventory().getItem(detached.getName());
		if(anotherBlob !is null)
		{
			this.server_Pickup(anotherBlob);
		}
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	// destroy built blob if somehow they got into inventory
	if(blob.hasTag("temp blob"))
	{
		blob.server_Die();
		blob.Untag("temp blob");
	}

	if(this.isMyPlayer() && blob.hasTag("material"))
	{
		SetHelp(this, "help inventory", "builder", "$Help_Block1$$Swap$$Help_Block2$           $KEY_HOLD$$KEY_F$", "", 3);
	}
}
