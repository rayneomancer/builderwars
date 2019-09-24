//make a small button for swapping tools ~r
const string swap_tool = "swap_tool";

void onInit(CBlob@ this)
{
	this.addCommandID(swap_tool);
	this.set_string("tool", "pickaxe");
}

void onCreateInventoryMenu( CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu )
{
	if(getRules().gamemode_name == "BW")
	{
    	MakeToolMenu(this, gridmenu);
	}
}

void MakeToolMenu( CBlob@ this, CGridMenu @invmenu )
{
    CInventory@ inv = this.getInventory();
    Vec2f pos( invmenu.getUpperLeftPosition().x + 0.5f*(invmenu.getLowerRightPosition().x - invmenu.getUpperLeftPosition().x) - 108,
                   invmenu.getUpperLeftPosition().y -132 );
	CGridMenu@ menu = CreateGridMenu( pos, this, Vec2f(1, 1), "Tool" );
	if (menu !is null)
	{
		//print("adding tool button");
		string tool_name;
		if(this.get_string("tool") == "pickaxe")
		{
			tool_name = "axe";
		}
		else if(this.get_string("tool") == "axe")
		{
			tool_name = "pickaxe";
		}
		menu.AddButton(tool_name + ".png", 0, tool_name, this.getCommandID(swap_tool));
		//print("added tool button");
	}
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
	if (cmd == this.getCommandID(swap_tool))
	{
		if(this.get_string("tool") == "pickaxe")
		{
			this.set_string("tool", "axe");
		}
		else if(this.get_string("tool") == "axe")
		{
			this.set_string("tool", "pickaxe");
		}
	}
}
