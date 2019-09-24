// Flame.as -- 
void onInit(CBlob@ this)
{
	this.getCurrentScript().tickFrequency = 15;
	
	this.SetLight(false);
	this.SetLightRadius(48.0f);
	this.SetLightColor(SColor(255, 255, 200, 50));
	this.set_u8("wettimer", 0);
	this.set_bool("wet", false);
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	u8 wettimer = blob.get_u8("wettimer");
	if(blob.get_bool("wet"))
	{
		wettimer++;
		blob.set_u8("wettimer", wettimer);
		if (wettimer >= 120)
		{
			blob.set_bool("wet", false);
			blob.Sync("wet", false);
		}
		return;
	}
	
	if (!getNet().isClient()) return;
	const u16 angle = blob.getAngleDegrees();
	const Vec2f offset = Vec2f(0, -1).RotateBy(angle);
	Vec2f pos = blob.getPosition();

	if (blob.get_u8("state") == 1)
	{	//a flame for each direction because im bad ~r
		if(offset.x == 0 && offset.y < 0)//up
		{
			ParticleAnimated(CFileMatcher("SmallFire3").getFirst(), 
				(this.getBlob().getPosition() + Vec2f(0,2)) + Vec2f(XORRandom(1), XORRandom(16) - 16), 
				Vec2f(0, 0), angle, 1.0f, 2, -0.25f, true);
		}
		else if(offset.x < 0 && offset.y > 0)//down
		{
			ParticleAnimated(CFileMatcher("SmallFire3").getFirst(), 
				(this.getBlob().getPosition() + Vec2f(0,1)) + Vec2f(XORRandom(1), XORRandom(16)), 
				Vec2f(0, 0), angle, 1.0f, 2, -0.25f, true);
		}
		else if (offset.x > 0 && offset.y > 0)//right
		{
			ParticleAnimated(CFileMatcher("SmallFire3").getFirst(), 
				(this.getBlob().getPosition() - Vec2f(1,0)) + Vec2f(XORRandom(16), XORRandom(1)), 
				Vec2f(0, 0), angle, 1.0f, 2, -0.25f, true);			
		}
		else if (offset.x < 0 && offset.y < 0)//left
		{
			ParticleAnimated(CFileMatcher("SmallFire3").getFirst(), 
				(this.getBlob().getPosition() + Vec2f(1,0)) - Vec2f(XORRandom(16), XORRandom(1)), 
				Vec2f(0, 0), angle, 1.0f, 2, -0.25f, true);			
		}
		blob.SetLight(true);
	}
	else
	{
		blob.SetLight(false);
	}

}
