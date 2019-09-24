#include "BW_Common.as"
#include "GameplayEvents.as"

void onInit(CRules@ this)
{
    SetupGameplayEvents(this);// this is used for ctf_trading.as, which awards players coins for various events
}

void onRender(CRules@ this)
{
	CPlayer@ p = getLocalPlayer();

	if (p is null || !p.isMyPlayer()) { return; }

	string propname = SPAWN_TIME_PROP_PREFIX + p.getUsername();
	if (p.getBlob() is null && this.exists(propname))
	{
		u32 spawn = Maths::Round((this.get_u32(propname) - getGameTime()) / getTicksASecond());

		if (spawn < 255)
		{
			string spawn_message = getTranslatedString("Respawning in: {SEC}").replace("{SEC}", "" + spawn);

			GUI::SetFont("hud");
			GUI::DrawText(spawn_message , Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
		}
	}
}