#define SERVER_ONLY
#include "BW_Common.as"
#include "HallCommon.as" // needed for the isUnderRaid function

u32 timer = 0;// used for warmup time

//hooks

void onPlayerLeave( CRules@ this, CPlayer@ player ){
    this.set_u32(SPAWN_TIME_PROP_PREFIX + player.getUsername(), 0);
}

void onPlayerDie( CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData ){
    handleSpawn(this, victim);
}

void onNewPlayerJoin( CRules@ this, CPlayer@ player ){
    handleSpawn(this, player);
}

void onPlayerRequestTeamChange( CRules@ this, CPlayer@ player, u8 newteam ){
    // kills a player upon switching teams
    if(newteam != player.getTeamNum() && player.getBlob() !is null)
        player.getBlob().server_Die();
}

void onTick(CRules@ this){
    u32 gameTime = getGameTime();
    //spawn time handling
    for(int i = 0; i < getPlayerCount(); i++){
        CPlayer@ player = getPlayer(i);
        string propname = SPAWN_TIME_PROP_PREFIX + player.getUsername();
        // if the player is not a spectator and is dead and is respawning...
        if(player !is null && player.getTeamNum() != this.getSpectatorTeamNum() && player.getBlob() is null && this.exists(propname)){
            u32 spawnTime = this.get_u32(propname);
            // ...and its time to respawn
            if(spawnTime > 0 && spawnTime <= gameTime){
                // ...then create their blob and clear the respawn prop
                Respawn(this, player);
            }
        }
    }
    const u8 state = this.getCurrentState();
    // if game is in warmup mode
    if(state == WARMUP){
        const int WARMUP_TIME = this.get_u32(WARMUP_TIME_PROP);
        // increment the timer
        if(enoughPlayersToStart()){
            timer++;
            this.SetGlobalMessage("Starting in... " + (WARMUP_TIME - Maths::Ceil(timer / getTicksASecond())) + " seconds");
        }
        else{
            timer = 0;
            this.SetGlobalMessage("Not enough players in each team for the game to start.\nPlease wait for someone to join...");
        }
        // when it has been WARMUP_TIME seconds, then start the game
        if(timer >= WARMUP_TIME * getTicksASecond()){
            this.SetCurrentState(GAME);
            this.SetGlobalMessage("");
        }
    }
    //if game is running, check win condition
    else if(state == GAME)
    {
        u8 blue_gold = this.get_u8(GOLD_PILE_COUNT_PREFIX + 0);
        u8 red_gold = this.get_u8(GOLD_PILE_COUNT_PREFIX + 1);
        //draw?? is this possible? if so, very very unlikely
        if(blue_gold == 0 && red_gold == 0) this.SetCurrentState(GAME_OVER);
        //blue win
        else if(blue_gold == 0) this.SetTeamWon(1);
        //red win
        else if(red_gold == 0) this.SetTeamWon(0);
        // if there is a winner, then end the game
        if(this.getTeamWon() >= 0) this.SetCurrentState(GAME_OVER);
    }
    //if the game is over..
    else if(state == GAME_OVER){
        //..and there is a winner..
        if(this.getTeamWon() >= 0){
            //..then set the global message
            // this will use whatever name is in the team.cfg file, so it is customizable later
            this.SetGlobalMessage("The " + this.getTeam(this.getTeamWon()).getName() + " has won!");
        }
        //otherwise its a draw
        else{
            this.SetGlobalMessage("The game has ended in a draw!");
        }
        //reset gold counts
        this.set_u8(GOLD_PILE_COUNT_PREFIX + 0, 0);
        this.set_u8(GOLD_PILE_COUNT_PREFIX + 1, 0);
    }
}

void onInit(CRules@ this){
    //read config file
    ConfigFile cfg = ConfigFile(CONFIG_FILE_PATH);
    this.set_u32(RESPAWN_TIME_PROP, cfg.read_u32(RESPAWN_TIME_PROP, 10));
    this.set_u32(WARMUP_TIME_PROP, cfg.read_u32(WARMUP_TIME_PROP, 180));
    //init the rest in the restart function
    onRestart(this);
}

void onRestart(CRules@ this){
    // game state management
    this.SetCurrentState(WARMUP);
    timer = 0;// reset the warmup timer.
    //set the respawn time for every player upon restarting
    u32 gameTime = getGameTime();
    for(int i = 0; i < getPlayerCount(); i++){
        CPlayer@ player = getPlayer(i);
        if(player !is null){
            handleSpawn(this, player);
        }
    }
}

//helper functions

void handleSpawn(CRules@ this, CPlayer@ player){
    //we dont want spectators spawning
    if(player.getTeamNum() == this.getSpectatorTeamNum()) return;
    this.set_u32(SPAWN_TIME_PROP_PREFIX + player.getUsername(), getGameTime()+getRespawnTime(this));
    // this is synced so that the client can see when they will respawn, used in BW_Interface.as
    this.Sync(SPAWN_TIME_PROP_PREFIX + player.getUsername(), true);
    player.client_RequestSpawn();// triggers the onPlayerRequestSpawn hook, important for team balancing
}

u32 getRespawnTime(CRules@ this){
    if(this.getCurrentState() == GAME) return this.get_u32(RESPAWN_TIME_PROP)*getTicksASecond();
    else return 0.5f*getTicksASecond(); // near instant respawn time during warmup/after end of game
}

int getTeamSize(int team)
{
    int count = 0;
    for(int i = 0; i < getPlayerCount(); i++)
    {
        CPlayer@ player = getPlayer(i);
        if(player.getTeamNum() == team){
            count++;
        }
    }
    return count;
}

bool enoughPlayersToStart()
{
    int numTeams = getRules().getTeamsCount();
    int smallestTeamSize = getTeamSize(0);
    for(int i = 1; i < numTeams; i++){
        int teamSize = getTeamSize(i);
        if(teamSize < smallestTeamSize){
            smallestTeamSize = teamSize;
        }
    }
    return smallestTeamSize > 0;
}

CBlob@ Respawn(CRules@ this, CPlayer@ player)
{
	if (player !is null)
	{
		// remove previous players blob
		CBlob @blob = player.getBlob();
		if (blob !is null){
			CBlob @blob = player.getBlob();
			blob.server_SetPlayer(null);
			blob.server_Die();
		}
		int team = player.getTeamNum();
		CBlob@ newBlob = server_CreateBlob("builder", team, getSpawnLocation(player));
		newBlob.server_SetPlayer(player);
		return newBlob;
	}

	return null;
}

Vec2f getSpawnLocation(CPlayer@ player)
{
    int teamnum = player.getTeamNum();
    CBlob@ pickSpawn = getBlobByNetworkID(player.getSpawnPoint());
    if (pickSpawn !is null &&
            pickSpawn.hasTag("respawn") && !isUnderRaid(pickSpawn) &&
            pickSpawn.getTeamNum() == teamnum)
    {
        return pickSpawn.getPosition();
    }

    CMap@ map = getMap();
    f32 x;
    if(map !is null)
    {
        if (teamnum == 0)
        {
            x = 32.0f;
        }
        else if (teamnum == 1)
        {
            x = map.tilemapwidth * map.tilesize - 32.0f;
        }
        return Vec2f(x, map.getLandYAtX(s32(x/map.tilesize))*map.tilesize - 16.0f);
    }

    return Vec2f(0,0);
}