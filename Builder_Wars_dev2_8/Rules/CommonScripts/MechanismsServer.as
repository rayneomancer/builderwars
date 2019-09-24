// MechanismsServer.as

#define SERVER_ONLY

#include "MechanismsCommon.as";

/////////////////////////////////////
// Mechanisms management
// done by rules, sits
// in background ticking away
/////////////////////////////////////

void onInit(CRules@ this)
{
	onRestart(this);
}

void onRestart(CRules@ this)
{
	MapPowerGrid grid(getMap());
	this.set("power grid", grid);
}

void onTick(CRules@ this)
{
	MapPowerGrid@ grid;
	if(!this.get("power grid", @grid)) return;

	float update_percent = 0.25; //every 4 ticks, whole thing is updated

	//impl - update
	if(getRules().gamemode_name == "BW")
	{
    	update_percent = 0.5; 
	}

	grid.update(Maths::Ceil(update_percent * grid.chunk_count));
}

void onRender(CRules@ this)
{
	if(g_debug == 1)
	{
		MapPowerGrid@ grid;
		if(!this.get("power grid", @grid)) return;

		grid.render();
	}
}
