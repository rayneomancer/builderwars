// spawn resources by makmoud98
// edits by rayne@ ~r
#include "MakeCrate.as"
#include "BW_Common.as"

const u8 MATERIALS_WAIT = 40; //seconds between free mats
const u8 MATERIALS_WAIT_WARMUP = 40; //seconds between free mats
const u8 SUPPLY_CRATE_WAIT = 180; //seconds

const u16 WOOD_RESUPPLY = 100;
const u16 STONE_RESUPPLY = 30;

const u16 WOOD_RESUPPLY_WARMUP = 300;
const u16 STONE_RESUPPLY_WARMUP = 100;
//property
const string SPAWN_ITEMS_TIMER_PREFIX = "bw mats: ";
const string NEXT_SUPPLY_CRATE_PROP = "nextsupplycrate";

void onRestart(CRules@ this)
{
    //restart everyone's timers
    for (uint i = 0; i < getPlayersCount(); ++i){
        CPlayer@ player = getPlayer(i);
        if(player !is null){
            string propname = SPAWN_ITEMS_TIMER_PREFIX + player.getUsername();
            this.set_u32(propname, getGameTime());
        }
    }
    this.set_u32(NEXT_SUPPLY_CRATE_PROP, 0);
}

void onInit(CRules@ this)
{
    onRestart(this);
}

void onTick(CRules@ this)
{
    if (!getNet().isServer())
        return;
    //if(this.getCurrentState() == WARMUP){
        for(int i = 0; i < getPlayersCount(); i++){
            CPlayer@ player = getPlayer(i);
            if(player !is null){
                CBlob@ blob = player.getBlob();
                if(blob !is null){
                    string propname = SPAWN_ITEMS_TIMER_PREFIX + player.getUsername();
                    u32 mat_timer = this.get_u32(propname);
                    if(mat_timer <= getGameTime()){
                        bool got_mats = setMaterials(blob, "mat_wood", (this.isWarmup() ? WOOD_RESUPPLY_WARMUP : WOOD_RESUPPLY));
                        got_mats = setMaterials(blob, "mat_stone", (this.isWarmup() ? STONE_RESUPPLY_WARMUP : STONE_RESUPPLY)) || got_mats;
                        if(got_mats){
                            this.set_u32(propname, getGameTime() + (this.isWarmup() ? MATERIALS_WAIT_WARMUP : MATERIALS_WAIT)*getTicksASecond());
                            this.Sync(propname, true);
                        }
                    }
                }
            }
        }
    //}
    if(this.getCurrentState() == GAME){
        u32 next_supply = this.get_u32(NEXT_SUPPLY_CRATE_PROP);
        if(next_supply == 0){
            this.set_u32(NEXT_SUPPLY_CRATE_PROP, getGameTime() + SUPPLY_CRATE_WAIT*getTicksASecond());
            this.Sync(NEXT_SUPPLY_CRATE_PROP, true);
        }
        else if(next_supply < getGameTime()){
            for(u8 i = 0; i < 2; i++){
                Vec2f droppos = this.get_Vec2f(GOLD_PILE_POS_PREFIX+i);
                CBlob@ crate = server_MakeCrateOnParachute("", "", 5, i, getDropPosition(droppos));
                if (crate !is null)
                {
                    crate.Tag("unpackall");
                    for (u8 i = 0; i < 2; i++)
                    {
                        CBlob@ mat = server_CreateBlob("mat_wood");
                        if (mat !is null)
                        {
                            crate.server_PutInInventory(mat);
                        }
                        CBlob@ mat1 = server_CreateBlob("mat_stone");
                        if (mat1 !is null)
                        {
                            crate.server_PutInInventory(mat1);
                        }
                    }
                }
                this.set_u32(NEXT_SUPPLY_CRATE_PROP, getGameTime() + SUPPLY_CRATE_WAIT*getTicksASecond());
                this.Sync(NEXT_SUPPLY_CRATE_PROP, true);
            }
        }
    }
}

// render gui for the player
void onRender(CRules@ this)
{
    CPlayer@ p = getLocalPlayer();
    if (p is null || !p.isMyPlayer()) { return; }

    string propname = SPAWN_ITEMS_TIMER_PREFIX + p.getUsername();
    string propname2 = NEXT_SUPPLY_CRATE_PROP;

    CBlob@ b = p.getBlob();
    if (b !is null)
    {
        if (this.exists(propname)) //resupply notification
        {
            u32 mat_timer = this.get_u32(propname);
            if (mat_timer > getGameTime())
            {
                string action = "Go Fight";
                if (this.isWarmup()) action = "Prepare for Battle";

                u32 secs = Maths::Ceil((mat_timer - getGameTime()) / getTicksASecond());
                string units = ((secs != 1) ? " seconds" : " second");
                GUI::SetFont("menu");
                GUI::DrawTextCentered(getTranslatedString("Next resupply in {SEC}{TIMESUFFIX}, {ACTION}!")
                    .replace("{SEC}", "" + secs)
                    .replace("{TIMESUFFIX}", getTranslatedString(units))
                    .replace("{ACTION}", getTranslatedString(action)),
                Vec2f(getScreenWidth() / 2, getScreenHeight() / 3 - 70.0f + Maths::Sin(getGameTime() / 3.0f) * 5.0f),
                SColor(255, 255, 55, 55));
            }
        }
        if(this.exists(propname2) && (this.getCurrentState() != WARMUP)) //supply crate notification ~r
        {
            u32 mat_timer = this.get_u32(propname2);
            if (mat_timer > getGameTime())
            {
                u32 secs = Maths::Ceil((mat_timer - getGameTime()) / getTicksASecond());
                string units = ((secs != 1) ? " seconds" : " second");
                GUI::SetFont("menu");
                if (secs <= 10) //only show it when it's about to drop
                {
                    GUI::DrawTextCentered(getTranslatedString("A Supply Crate will drop at your gold pile in {SEC}{TIMESUFFIX}.")
                        .replace("{SEC}", "" + secs)
                        .replace("{TIMESUFFIX}", getTranslatedString(units)),
                    Vec2f(getScreenWidth() / 2, getScreenHeight() / 3 - 95.0f + Maths::Sin(getGameTime() / 3.0f) * 5.0f),
                    SColor(255, 255, 55, 55));
                }
            }
        }
    }
}

bool setMaterials(CBlob@ blob, const string &in name, const int quantity)
{
    CInventory@ inv = blob.getInventory();
    int count = inv.getCount(name) % 500;
    if(count > 0 || !inv.isFull()){
        CBlob@ mat = server_CreateBlobNoInit(name);
        mat.Tag('custom quantity');
        mat.Init();
        mat.server_SetQuantity(Maths::Min(quantity, 500 - count));
        blob.server_PutInInventory(mat);
        return true;
    }
    return false;
}