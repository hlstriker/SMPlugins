#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include "../../../Libraries/Donators/donators"
#include "../../../Libraries/ClientCookies/client_cookies"
#include "../../../Libraries/FileDownloader/file_downloader"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../../Libraries/ModelSkinManager/model_skin_manager"
#include "../../../Plugins/Unsafe/unsafe_gloves"
#include "../../../RandomIncludes/kztimer"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Donator Item: Player Models";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to use a custom model.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bIsFileDownloading;
new Handle:g_aDownloadQueue;

new bool:g_bModelsEnabled;

new Handle:g_hFwd_OnModelSet;
new g_iItemBits[MAXPLAYERS+1];
new bool:g_bUsingArmsModel[MAXPLAYERS+1];

new bool:g_bLibLoaded_ModelSkinManager;
new bool:g_bLibLoaded_KZTimer;

new const String:g_szPlayerModelNames[][] =
{
	"Ada Wong",
	"Deadpool",
	"Duke Nukem",
	"Ezio Auditore da Firenze",
	"Hitler",
	"Hitman Agent 47",
	"Lilith",
	"Nanosuit",
	"Punished \"Venom\" Snake",
	"Reina Kousaka",
	"Rocket Raccoon",
	"Samus Aran - Zero Suit",
	"Goku"
};

new const String:g_szPlayerModelPaths[][] =
{
	"models/player/custom_player/swoobles/ada_wong_2/ada_wong.mdl",					// Ada Wong
	"models/player/custom_player/swoobles/deadpool_2/deadpool.mdl",					// Deadpool
	"models/player/custom_player/swoobles/duke_2/duke.mdl",							// Duke Nukem
	"models/player/custom_player/swoobles/ezio_2/ezio.mdl",							// Ezio Auditore da Firenze
	"models/player/custom_player/swoobles/hitler_3/hitler.mdl",						// Hitler
	"models/player/custom_player/swoobles/hitman_2/hitman.mdl",						// Hitman Agent 47
	"models/player/custom_player/swoobles/lilith_2/lilith.mdl",						// Lilith
	"models/player/custom_player/swoobles/nanosuit_2/nanosuit.mdl",					// Nanosuit
	"models/player/custom_player/swoobles/sneaking_suit_2/sneaking_suit.mdl",		// Punished "Venom" Snake
	"models/player/custom_player/swoobles/reina_kousaka_2/reina_kousaka.mdl",		// Reina Kousaka
	"models/player/custom_player/swoobles/rocket_raccoon_2/rocket_raccoon.mdl",		// Rocket Raccoon
	"models/player/custom_player/swoobles/samus_2/samus.mdl",						// Samus Aran - Zero Suit
	"models/player/custom_player/swoobles/goku/goku.mdl"							// Goku
};

new const String:g_szArmsModelPaths[][] =
{
	"",		// Ada Wong
	"",		// Deadpool
	"",		// Duke Nukem
	"",		// Ezio Auditore da Firenze
	"",		// Hitler
	"",		// Hitman Agent 47
	"",		// Lilith
	"",		// Nanosuit
	"",		// Punished "Venom" Snake
	"",		// Reina Kousaka
	"",		// Rocket Raccoon
	"",		// Samus Aran - Zero Suit
	"models/player/custom_player/swoobles/goku/arms.mdl"	// Goku
};

new const String:g_szPlayerModelFiles[][] =
{
	// Ada Wong
	"models/player/custom_player/swoobles/ada_wong_2/ada_wong.dx90.vtx",
	"models/player/custom_player/swoobles/ada_wong_2/ada_wong.phy",
	"models/player/custom_player/swoobles/ada_wong_2/ada_wong.vvd",
	
	"materials/swoobles/player/re6_ada_wong_2/ada_bjlips.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_chest_blue.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_chest_red.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_eye.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_eye.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_eye_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_eyelash.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_eyelash.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_eyelash_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_face.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_face.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_face_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_hair.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_hair.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_hair_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_hair2.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_hand.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_hand.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_hand_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_misc.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_misc.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_misc_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_pants.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_pants.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_pants_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_shirt_blue.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_shirt_blue.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_shirt_normal.vtf",
	"materials/swoobles/player/re6_ada_wong_2/ada_shirt_red.vmt",
	"materials/swoobles/player/re6_ada_wong_2/ada_shirt_red.vtf",
	
	// Deadpool
	"models/player/custom_player/swoobles/deadpool_2/deadpool.dx90.vtx",
	"models/player/custom_player/swoobles/deadpool_2/deadpool.phy",
	"models/player/custom_player/swoobles/deadpool_2/deadpool.vvd",
	
	"materials/swoobles/player/deadpool_2/deadpool_body_color.vmt",
	"materials/swoobles/player/deadpool_2/deadpool_body_color_blue.vmt",
	"materials/swoobles/player/deadpool_2/deadpool_eyes.vmt",
	"materials/swoobles/player/deadpool_2/deadpool_misc_color.vmt",
	"materials/swoobles/player/deadpool_2/deadpool_misc_color_blue.vmt",
	"materials/swoobles/player/deadpool_2/deadpool_misc_metal.vmt",
	"materials/swoobles/player/deadpool_2/deadpoolsword_color.vmt",
	"materials/swoobles/player/deadpool_2/deadpool_body_color.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_body_color_blue.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_body_norm.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_detail.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_misc_color.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_misc_color_blue.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_misc_exp2.vtf",
	"materials/swoobles/player/deadpool_2/deadpool_misc_norm.vtf",
	"materials/swoobles/player/deadpool_2/deadpoolsword_color.vtf",
	"materials/swoobles/player/deadpool_2/deadpoolsword_norm.vtf",
	
	// Duke Nukem
	"models/player/custom_player/swoobles/duke_2/duke.phy",
	"models/player/custom_player/swoobles/duke_2/duke.dx90.vtx",
	"models/player/custom_player/swoobles/duke_2/duke.vvd",
	
	"materials/swoobles/player/duke_2/duke_body.vmt",
	"materials/swoobles/player/duke_2/duke_body_blue.vmt",
	"materials/swoobles/player/duke_2/duke_fingers.vmt",
	"materials/swoobles/player/duke_2/duke_hand.vmt",
	"materials/swoobles/player/duke_2/duke_hand_blue.vmt",
	"materials/swoobles/player/duke_2/duke_head.vmt",
	"materials/swoobles/player/duke_2/duke_jeans.vmt",
	"materials/swoobles/player/duke_2/duke_shades.vmt",
	"materials/swoobles/player/duke_2/duke_body.vtf",
	"materials/swoobles/player/duke_2/duke_body_blue.vtf",
	"materials/swoobles/player/duke_2/duke_body_normal.vtf",
	"materials/swoobles/player/duke_2/duke_hand.vtf",
	"materials/swoobles/player/duke_2/duke_hand_blue.vtf",
	"materials/swoobles/player/duke_2/duke_hand_normal.vtf",
	"materials/swoobles/player/duke_2/duke_head.vtf",
	"materials/swoobles/player/duke_2/duke_head_normal.vtf",
	"materials/swoobles/player/duke_2/duke_lightwarp.vtf",
	"materials/swoobles/player/duke_2/duke_shades.vtf",
	"materials/swoobles/player/duke_2/duke_shades_normal.vtf",
	
	// Ezio Auditore da Firenze
	"models/player/custom_player/swoobles/ezio_2/ezio.dx90.vtx",
	"models/player/custom_player/swoobles/ezio_2/ezio.phy",
	"models/player/custom_player/swoobles/ezio_2/ezio.vvd",
	
	"materials/swoobles/player/ezio_2/cr_universal_teethclean_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/eyes_diffuse.vtf",
	"materials/swoobles/player/ezio_2/universal_male_hand_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/universal_male_hand_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_armshield_r3_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_armshield_r3_diffusemap_blue.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_blason_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_blason_diffusemap_blue.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_boots_r3_4_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_bracer_a_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_chest_r3_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_chest_r3_diffusemap_blue.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_down_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_down_diffusemap_blue.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_top_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_gant_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_head_old_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_hiddenbladegun_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_poutch_a_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_shoulderpad_r3_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/cr_u_ezio_shoulderpad_r3_diffusemap_blue.vmt",
	"materials/swoobles/player/ezio_2/cr_universal_teethclean_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/eyes_diffuse.vmt",
	"materials/swoobles/player/ezio_2/universal_male_hand_diffusemap.vmt",
	"materials/swoobles/player/ezio_2/bumpmap_flat.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_armshield_r3_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_armshield_r3_diffusemap_blue.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_armshield_r3_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_blason_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_blason_diffusemap_blue.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_blason_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_boots_r3_4_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_boots_r3_4_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_bracer_a_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_bracer_a_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_chest_r3_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_chest_r3_diffusemap_blue.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_down_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_down_diffusemap_blue.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_down_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_top_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_clothes_top_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_gant_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_head_old_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_head_old_normalmap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_hiddenbladegun_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_poutch_a_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_shoulderpad_r3_diffusemap.vtf",
	"materials/swoobles/player/ezio_2/cr_u_ezio_shoulderpad_r3_diffusemap_blue.vtf",
	
	// Hitler
	"models/player/custom_player/swoobles/hitler_3/hitler.dx90.vtx",
	"models/player/custom_player/swoobles/hitler_3/hitler.phy",
	"models/player/custom_player/swoobles/hitler_3/hitler.vvd",
	
	"materials/swoobles/player/hitler_2/hitlerbody_blue.vmt",
	"materials/swoobles/player/hitler_2/hitlerbody_red.vmt",
	"materials/swoobles/player/hitler_2/hitlerhead_colspec.vmt",
	"materials/swoobles/player/hitler_2/hitlerbody_blue.vtf",
	"materials/swoobles/player/hitler_2/hitlerbody_normal.vtf",
	"materials/swoobles/player/hitler_2/hitlerbody_red.vtf",
	"materials/swoobles/player/hitler_2/hitlerhead_colspec.vtf",
	"materials/swoobles/player/hitler_2/hitlerhead_normal.vtf",
	
	// Hitman Agent 47
	"models/player/custom_player/swoobles/hitman_2/hitman.phy",
	"models/player/custom_player/swoobles/hitman_2/hitman.dx90.vtx",
	"models/player/custom_player/swoobles/hitman_2/hitman.vvd",
	
	"materials/swoobles/player/hitman_2/earpiece_d.vmt",
	"materials/swoobles/player/hitman_2/eyes_d.vmt",
	"materials/swoobles/player/hitman_2/face_d.vmt",
	"materials/swoobles/player/hitman_2/gloves_d.vmt",
	"materials/swoobles/player/hitman_2/hands_d.vmt",
	"materials/swoobles/player/hitman_2/jacket_blue.vmt",
	"materials/swoobles/player/hitman_2/jacket_red.vmt",
	"materials/swoobles/player/hitman_2/lashes_d.vmt",
	"materials/swoobles/player/hitman_2/shirt_d.vmt",
	"materials/swoobles/player/hitman_2/tie_blue.vmt",
	"materials/swoobles/player/hitman_2/tie_red.vmt",
	"materials/swoobles/player/hitman_2/trousers_blue.vmt",
	"materials/swoobles/player/hitman_2/trousers_red.vmt",
	"materials/swoobles/player/hitman_2/earpiece_d.vtf",
	"materials/swoobles/player/hitman_2/earpiece_n.vtf",
	"materials/swoobles/player/hitman_2/eyes_d.vtf",
	"materials/swoobles/player/hitman_2/eyes_n.vtf",
	"materials/swoobles/player/hitman_2/face_d.vtf",
	"materials/swoobles/player/hitman_2/face_n.vtf",
	"materials/swoobles/player/hitman_2/gloves_d.vtf",
	"materials/swoobles/player/hitman_2/gloves_n.vtf",
	"materials/swoobles/player/hitman_2/hands_d.vtf",
	"materials/swoobles/player/hitman_2/hands_n.vtf",
	"materials/swoobles/player/hitman_2/jacket_blue.vtf",
	"materials/swoobles/player/hitman_2/jacket_n.vtf",
	"materials/swoobles/player/hitman_2/jacket_red.vtf",
	"materials/swoobles/player/hitman_2/lashes_d.vtf",
	"materials/swoobles/player/hitman_2/shirt_d.vtf",
	"materials/swoobles/player/hitman_2/shirt_n.vtf",
	"materials/swoobles/player/hitman_2/tie_blue.vtf",
	"materials/swoobles/player/hitman_2/tie_n.vtf",
	"materials/swoobles/player/hitman_2/tie_red.vtf",
	"materials/swoobles/player/hitman_2/trousers_blue.vtf",
	"materials/swoobles/player/hitman_2/trousers_n.vtf",
	"materials/swoobles/player/hitman_2/trousers_red.vtf",
	
	// Lilith
	"models/player/custom_player/swoobles/lilith_2/lilith.dx90.vtx",
	"models/player/custom_player/swoobles/lilith_2/lilith.phy",
	"models/player/custom_player/swoobles/lilith_2/lilith.vvd",
	
	"materials/swoobles/player/lilith_2/body_blue.vmt",
	"materials/swoobles/player/lilith_2/body_blue.vtf",
	"materials/swoobles/player/lilith_2/head_blue.vmt",
	"materials/swoobles/player/lilith_2/head_blue.vtf",
	"materials/swoobles/player/lilith_2/body_red.vmt",
	"materials/swoobles/player/lilith_2/body_red.vtf",
	"materials/swoobles/player/lilith_2/head_red.vmt",
	"materials/swoobles/player/lilith_2/head_red.vtf",
	"materials/swoobles/player/lilith_2/body_n.vtf",
	"materials/swoobles/player/lilith_2/head_n.vtf",
	
	// Nanosuit
	"models/player/custom_player/swoobles/nanosuit_2/nanosuit.dx90.vtx",
	"models/player/custom_player/swoobles/nanosuit_2/nanosuit.phy",
	"models/player/custom_player/swoobles/nanosuit_2/nanosuit.vvd",
	
	"materials/swoobles/player/nanosuit_2/arms_blue.vmt",
	"materials/swoobles/player/nanosuit_2/arms_red.vmt",
	"materials/swoobles/player/nanosuit_2/hands_blue.vmt",
	"materials/swoobles/player/nanosuit_2/hands_red.vmt",
	"materials/swoobles/player/nanosuit_2/helmet_blue.vmt",
	"materials/swoobles/player/nanosuit_2/helmet_pt_blue.vmt",
	"materials/swoobles/player/nanosuit_2/helmet_pt_red.vmt",
	"materials/swoobles/player/nanosuit_2/helmet_red.vmt",
	"materials/swoobles/player/nanosuit_2/legs_blue.vmt",
	"materials/swoobles/player/nanosuit_2/legs_red.vmt",
	"materials/swoobles/player/nanosuit_2/torso_blue.vmt",
	"materials/swoobles/player/nanosuit_2/torso_red.vmt",
	"materials/swoobles/player/nanosuit_2/visor_blue.vmt",
	"materials/swoobles/player/nanosuit_2/visor_red.vmt",
	"materials/swoobles/player/nanosuit_2/arms_blue.vtf",
	"materials/swoobles/player/nanosuit_2/arms_normal.vtf",
	"materials/swoobles/player/nanosuit_2/arms_red.vtf",
	"materials/swoobles/player/nanosuit_2/hands_blue.vtf",
	"materials/swoobles/player/nanosuit_2/hands_normal.vtf",
	"materials/swoobles/player/nanosuit_2/hands_red.vtf",
	"materials/swoobles/player/nanosuit_2/helmet_blue.vtf",
	"materials/swoobles/player/nanosuit_2/helmet_normal.vtf",
	"materials/swoobles/player/nanosuit_2/helmet_pt_blue.vtf",
	"materials/swoobles/player/nanosuit_2/helmet_pt_red.vtf",
	"materials/swoobles/player/nanosuit_2/helmet_red.vtf",
	"materials/swoobles/player/nanosuit_2/legs_blue.vtf",
	"materials/swoobles/player/nanosuit_2/legs_normal.vtf",
	"materials/swoobles/player/nanosuit_2/legs_red.vtf",
	"materials/swoobles/player/nanosuit_2/torso_blue.vtf",
	"materials/swoobles/player/nanosuit_2/torso_normal.vtf",
	"materials/swoobles/player/nanosuit_2/torso_red.vtf",
	"materials/swoobles/player/nanosuit_2/visor_blue.vtf",
	"materials/swoobles/player/nanosuit_2/visor_normal.vtf",
	"materials/swoobles/player/nanosuit_2/visor_red.vtf",
	
	// Punished "Venom" Snake
	"models/player/custom_player/swoobles/sneaking_suit_2/sneaking_suit.dx90.vtx",
	"models/player/custom_player/swoobles/sneaking_suit_2/sneaking_suit.phy",
	"models/player/custom_player/swoobles/sneaking_suit_2/sneaking_suit.vvd",
	
	"materials/swoobles/player/sneaking_suit_2/cqc_knife_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/diamond_dog_emblem_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/eyeball_source.vmt",
	"materials/swoobles/player/sneaking_suit_2/sna0_wmcs0_def_bsm.vmt",
	"materials/swoobles/player/sneaking_suit_2/sna2_eyelashes_bsm_alp.vmt",
	"materials/swoobles/player/sneaking_suit_2/sna2_face0_pach_bsm.vmt",
	"materials/swoobles/player/sneaking_suit_2/sna2_pacth0_def_bsm_alp.vmt",
	"materials/swoobles/player/sneaking_suit_2/snake_horn_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/snake_robotarm_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/snake_uniform_od.vmt",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_arm_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_arm_d_blue.vmt",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_d_blue.vmt",
	"materials/swoobles/player/sneaking_suit_2/venom_snake_face_d.vmt",
	"materials/swoobles/player/sneaking_suit_2/venom_snake_hair.vmt",
	"materials/swoobles/player/sneaking_suit_2/venom_snake_hair_alp.vmt",
	"materials/swoobles/player/sneaking_suit_2/clothes_wrp.vtf",
	"materials/swoobles/player/sneaking_suit_2/cqc_knife_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/cqc_knife_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/diamond_dog_emblem_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/diamond_dog_emblem_exp.vtf",
	"materials/swoobles/player/sneaking_suit_2/diamond_dog_emblem_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/eyeball_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/eyeball_source.vtf",
	"materials/swoobles/player/sneaking_suit_2/green.vtf",
	"materials/swoobles/player/sneaking_suit_2/hairwarp_gray.vtf",
	"materials/swoobles/player/sneaking_suit_2/phongwarp_gray.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna0_wmcs0_def_bsm.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna0_wmcs0_def_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna2_eyelashes_bsm_alp.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna2_face0_pach_bsm.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna2_face0_pach_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna2_hair0_def_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna2_pacth0_def_bsm_alp.vtf",
	"materials/swoobles/player/sneaking_suit_2/sna2_pacth0_def_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_horn_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_horn_n.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_horn_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_robotarm_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_robotarm_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_uniform_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/snake_uniform_od.vtf",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_arm_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_arm_d_blue.vtf",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_arm_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_d_blue.vtf",
	"materials/swoobles/player/sneaking_suit_2/sneaking_suit_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/venom_snake_face_d.vtf",
	"materials/swoobles/player/sneaking_suit_2/venom_snake_face_normal.vtf",
	"materials/swoobles/player/sneaking_suit_2/venom_snake_hair.vtf",
	"materials/swoobles/player/sneaking_suit_2/white2.vtf",
	"materials/swoobles/player/sneaking_suit_2/white3.vtf",
	
	// Reina Kousaka
	"models/player/custom_player/swoobles/reina_kousaka_2/reina_kousaka.phy",
	"models/player/custom_player/swoobles/reina_kousaka_2/reina_kousaka.dx90.vtx",
	"models/player/custom_player/swoobles/reina_kousaka_2/reina_kousaka.vvd",
	
	"materials/swoobles/player/reina_kousaka_2/drzka.vmt",
	"materials/swoobles/player/reina_kousaka_2/obleceni.vmt",
	"materials/swoobles/player/reina_kousaka_2/obleceni_blue.vmt",
	"materials/swoobles/player/reina_kousaka_2/telo.vmt",
	"materials/swoobles/player/reina_kousaka_2/vlasy.vmt",
	"materials/swoobles/player/reina_kousaka_2/drzka.vtf",
	"materials/swoobles/player/reina_kousaka_2/obleceni.vtf",
	"materials/swoobles/player/reina_kousaka_2/obleceni_blue.vtf",
	"materials/swoobles/player/reina_kousaka_2/telo.vtf",
	"materials/swoobles/player/reina_kousaka_2/vlasy.vtf",
	
	// Rocket Raccoon
	"models/player/custom_player/swoobles/rocket_raccoon_2/rocket_raccoon.dx90.vtx",
	"models/player/custom_player/swoobles/rocket_raccoon_2/rocket_raccoon.phy",
	"models/player/custom_player/swoobles/rocket_raccoon_2/rocket_raccoon.vvd",
	
	"materials/swoobles/player/rocket_raccoon_2/body_blue.vmt",
	"materials/swoobles/player/rocket_raccoon_2/body_red.vmt",
	"materials/swoobles/player/rocket_raccoon_2/head.vmt",
	"materials/swoobles/player/rocket_raccoon_2/head_1.vmt",
	"materials/swoobles/player/rocket_raccoon_2/body_blue.vtf",
	"materials/swoobles/player/rocket_raccoon_2/body_n.vtf",
	"materials/swoobles/player/rocket_raccoon_2/body_red.vtf",
	"materials/swoobles/player/rocket_raccoon_2/body_s.vtf",
	"materials/swoobles/player/rocket_raccoon_2/head.vtf",
	"materials/swoobles/player/rocket_raccoon_2/head_n.vtf",
	"materials/swoobles/player/rocket_raccoon_2/head_s.vtf",
	
	// Samus Aran - Zero Suit
	"models/player/custom_player/swoobles/samus_2/samus.phy",
	"models/player/custom_player/swoobles/samus_2/samus.dx90.vtx",
	"models/player/custom_player/swoobles/samus_2/samus.vvd",
	
	"materials/swoobles/player/samus_2/body_diffuse.vmt",
	"materials/swoobles/player/samus_2/body_diffuse_pink.vmt",
	"materials/swoobles/player/samus_2/emissive.vmt",
	"materials/swoobles/player/samus_2/emissive_pink.vmt",
	"materials/swoobles/player/samus_2/eye_diffuse.vmt",
	"materials/swoobles/player/samus_2/eyelash_lower.vmt",
	"materials/swoobles/player/samus_2/eyelash_upper.vmt",
	"materials/swoobles/player/samus_2/face_diffuse.vmt",
	"materials/swoobles/player/samus_2/gun_diffuse.vmt",
	"materials/swoobles/player/samus_2/hair_diffuse.vmt",
	"materials/swoobles/player/samus_2/holster.vmt",
	"materials/swoobles/player/samus_2/body_bump.vtf",
	"materials/swoobles/player/samus_2/body_diffuse.vtf",
	"materials/swoobles/player/samus_2/body_diffuse_pink.vtf",
	"materials/swoobles/player/samus_2/emissive.vtf",
	"materials/swoobles/player/samus_2/emissive_pink.vtf",
	"materials/swoobles/player/samus_2/eye_bump.vtf",
	"materials/swoobles/player/samus_2/eye_diffuse.vtf",
	"materials/swoobles/player/samus_2/eyelash_lower.vtf",
	"materials/swoobles/player/samus_2/eyelash_upper.vtf",
	"materials/swoobles/player/samus_2/face_bump.vtf",
	"materials/swoobles/player/samus_2/face_diffuse.vtf",
	"materials/swoobles/player/samus_2/gun_bump.vtf",
	"materials/swoobles/player/samus_2/gun_diffuse.vtf",
	"materials/swoobles/player/samus_2/hair_bump.vtf",
	"materials/swoobles/player/samus_2/hair_diffuse.vtf",
	"materials/swoobles/player/samus_2/holster.vtf",
	"materials/swoobles/player/samus_2/holster_bump.vtf",
	
	// Goku
	"models/player/custom_player/swoobles/goku/goku.phy",
	"models/player/custom_player/swoobles/goku/goku.dx90.vtx",
	"models/player/custom_player/swoobles/goku/goku.vvd",
	
	"models/player/custom_player/swoobles/goku/arms.dx90.vtx",
	"models/player/custom_player/swoobles/goku/arms.vvd",
	
	"materials/swoobles/player/goku/belt.vmt",
	"materials/swoobles/player/goku/body.vmt",
	"materials/swoobles/player/goku/boot.vmt",
	"materials/swoobles/player/goku/boot2.vmt",
	"materials/swoobles/player/goku/boot3.vmt",
	"materials/swoobles/player/goku/boot4.vmt",
	"materials/swoobles/player/goku/eyebrow.vmt",
	"materials/swoobles/player/goku/eyes.vmt",
	"materials/swoobles/player/goku/face.vmt",
	"materials/swoobles/player/goku/hair.vmt",
	"materials/swoobles/player/goku/hand.vmt",
	"materials/swoobles/player/goku/pant.vmt",
	"materials/swoobles/player/goku/pant_blue.vmt",
	"materials/swoobles/player/goku/shirt.vmt",
	"materials/swoobles/player/goku/top.vmt",
	"materials/swoobles/player/goku/top_blue.vmt",
	"materials/swoobles/player/goku/wristband.vmt",
	"materials/swoobles/player/goku/belt.vtf",
	"materials/swoobles/player/goku/belt_normal.vtf",
	"materials/swoobles/player/goku/body.vtf",
	"materials/swoobles/player/goku/body_normal.vtf",
	"materials/swoobles/player/goku/boot.vtf",
	"materials/swoobles/player/goku/boot_normal.vtf",
	"materials/swoobles/player/goku/boot2.vtf",
	"materials/swoobles/player/goku/boot3.vtf",
	"materials/swoobles/player/goku/boot4.vtf",
	"materials/swoobles/player/goku/eye_lightwarp.vtf",
	"materials/swoobles/player/goku/eyebrow.vtf",
	"materials/swoobles/player/goku/face.vtf",
	"materials/swoobles/player/goku/face_normal.vtf",
	"materials/swoobles/player/goku/facewarp.vtf",
	"materials/swoobles/player/goku/hair.vtf",
	"materials/swoobles/player/goku/hair_normal.vtf",
	"materials/swoobles/player/goku/hand.vtf",
	"materials/swoobles/player/goku/hand_normal.vtf",
	"materials/swoobles/player/goku/iris.vtf",
	"materials/swoobles/player/goku/pant.vtf",
	"materials/swoobles/player/goku/pant_blue.vtf",
	"materials/swoobles/player/goku/pant_normal.vtf",
	"materials/swoobles/player/goku/shirt.vtf",
	"materials/swoobles/player/goku/shirt_normal.vtf",
	"materials/swoobles/player/goku/skin_lightwarp_blue1.vtf",
	"materials/swoobles/player/goku/top.vtf",
	"materials/swoobles/player/goku/top_blue.vtf",
	"materials/swoobles/player/goku/top_normal.vtf",
	"materials/swoobles/player/goku/wristband.vtf"
};


public OnPluginStart()
{
	CreateConVar("donator_item_player_models_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnModelSet = CreateGlobalForward("DItemPlayerModels_OnModelSet", ET_Ignore, Param_Cell);
	
	g_aDownloadQueue = CreateArray(PLATFORM_MAX_PATH);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
	g_bLibLoaded_KZTimer = LibraryExists("KZTimer");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = true;
	}
	else if(StrEqual(szName, "KZTimer"))
	{
		g_bLibLoaded_KZTimer = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = false;
	}
	else if(StrEqual(szName, "KZTimer"))
	{
		g_bLibLoaded_KZTimer = false;
	}
}

public OnMapStart()
{
	InitFiles();
}

InitFiles()
{
	g_bModelsEnabled = false;
	
	// First loop through the files and download them if needed.
	for(new i=0; i<sizeof(g_szPlayerModelPaths); i++)
		DownloadFileIfNeeded(g_szPlayerModelPaths[i]);
	
	for(new i=0; i<sizeof(g_szArmsModelPaths); i++)
	{
		if(StrEqual(g_szArmsModelPaths[i], ""))
			continue;
		
		DownloadFileIfNeeded(g_szArmsModelPaths[i]);
	}
	
	for(new i=0; i<sizeof(g_szPlayerModelFiles); i++)
	{
		if(g_szPlayerModelFiles[i][0])
			DownloadFileIfNeeded(g_szPlayerModelFiles[i]);
	}
	
	// Return if any file is still downloading.
	if(g_bIsFileDownloading)
		return;
	
	// No files are downloading. It's safe to precache the files now.
	for(new i=0; i<sizeof(g_szPlayerModelPaths); i++)
	{
		AddFileToDownloadsTable(g_szPlayerModelPaths[i]);
		PrecacheModel(g_szPlayerModelPaths[i], true);
	}
	
	for(new i=0; i<sizeof(g_szArmsModelPaths); i++)
	{
		if(StrEqual(g_szArmsModelPaths[i], ""))
			continue;
		
		AddFileToDownloadsTable(g_szArmsModelPaths[i]);
		PrecacheModel(g_szArmsModelPaths[i], true);
	}
	
	for(new i=0; i<sizeof(g_szPlayerModelFiles); i++)
	{
		if(g_szPlayerModelFiles[i][0])
			AddFileToDownloadsTable(g_szPlayerModelFiles[i]);
	}
	
	g_bModelsEnabled = true;
}

public OnClientConnected(iClient)
{
	g_iItemBits[iClient] = 0;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(!ClientCookies_HasCookie(iClient, CC_TYPE_DONATOR_ITEM_PLAYER_MODELS))
		return;
	
	g_iItemBits[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_DONATOR_ITEM_PLAYER_MODELS);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("donatoritem_player_models");
	
	CreateNative("DItemPlayerModels_HasUsableModelActivated", _DItemPlayerModels_HasUsableModelActivated);
	return APLRes_Success;
}

public _DItemPlayerModels_HasUsableModelActivated(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
		return false;
	
	new iClient = GetNativeCell(1);
	if(GetRandomActivatedItemIndex(iClient) < 0)
		return false;
	
	return true;
}

GetRandomActivatedItemIndex(iClient)
{
	if(!Donators_IsDonator(iClient))
		return -1;
	
	decl iActivated[sizeof(g_szPlayerModelNames)];
	new iNumFound;
	
	for(new i=0; i<sizeof(g_szPlayerModelNames); i++)
	{
		if(!(g_iItemBits[iClient] & (1<<i)))
			continue;
		
		iActivated[iNumFound++] = i;
	}
	
	if(!iNumFound)
		return -1;
	
	return iActivated[GetRandomInt(0, iNumFound-1)];
}

public OnClientPutInServer(iClient)
{
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(g_bLibLoaded_ModelSkinManager)
		return;
	
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	SpawnPost(iClient);
}

public MSManager_OnSpawnPost(iClient)
{
	SpawnPost(iClient);
}

SpawnPost(iClient)
{
	g_bUsingArmsModel[iClient] = false;
	
	if(!g_bModelsEnabled)
		return;
	
	new iItemIndex = GetRandomActivatedItemIndex(iClient);
	if(iItemIndex < 0)
		return;
	
	SetPlayerModel(iClient, iItemIndex);
}

public Action:Gloves_OnApply(iClient)
{
	if(g_bUsingArmsModel[iClient])
		return Plugin_Handled;
	
	return Plugin_Continue;
}

SetPlayerModel(iClient, iItemIndex)
{
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		MSManager_SetPlayerModel(iClient, g_szPlayerModelPaths[iItemIndex]);
		
		if(!StrEqual(g_szArmsModelPaths[iItemIndex], ""))
		{
			MSManager_SetArmsModel(iClient, g_szArmsModelPaths[iItemIndex]);
			g_bUsingArmsModel[iClient] = true;
		}
		#else
		SetEntityModel(iClient, g_szPlayerModelPaths[iItemIndex]);
		#endif
	}
	else
	{
		SetEntityModel(iClient, g_szPlayerModelPaths[iItemIndex]);
	}
	
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T: SetEntProp(iClient, Prop_Send, "m_nSkin", 0);
		case CS_TEAM_CT: SetEntProp(iClient, Prop_Send, "m_nSkin", 1);
	}
	
	_DItemPlayerModels_OnModelSet(iClient);
	
	return true;
}

_DItemPlayerModels_OnModelSet(iClient)
{
	Call_StartForward(g_hFwd_OnModelSet);
	Call_PushCell(iClient);
	Call_Finish();
}


///////////////////
// START SETTINGS
///////////////////
public Donators_OnRegisterSettingsReady()
{
	Donators_RegisterSettings("Player Models", OnSettingsMenu);
}

public OnSettingsMenu(iClient)
{
	DisplayMenu_ToggleItems(iClient);
}

CloseKZTimerMenu(iClient)
{
	if(g_bLibLoaded_KZTimer)
	{
		#if defined _KZTimer_included
		KZTimer_StopUpdatingOfClimbersMenu(iClient);
		#endif
	}
}

DisplayMenu_ToggleItems(iClient, iPosition=0)
{
	CloseKZTimerMenu(iClient);
	
	new Handle:hMenu = CreateMenu(MenuHandle_ToggleItems);
	SetMenuTitle(hMenu, "Player Models");
	
	decl String:szInfo[6], String:szBuffer[64];
	Format(szBuffer, sizeof(szBuffer), "%sNone", (g_iItemBits[iClient] == 0) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, "-1", szBuffer);
	
	for(new i=0; i<sizeof(g_szPlayerModelNames); i++)
	{
		IntToString(i, szInfo, sizeof(szInfo));
		Format(szBuffer, sizeof(szBuffer), "%s%s", (g_iItemBits[iClient] & (1<<i)) ? "[\xE2\x9C\x93] " : "", g_szPlayerModelNames[i]);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iPosition, 0))
	{
		CPrintToChat(iClient, "{green}-- {red}This category has no items.");
		Donators_OpenSettingsMenu(iClient);
		return;
	}
}

public MenuHandle_ToggleItems(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		Donators_OpenSettingsMenu(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iItemIndex = StringToInt(szInfo);
	
	if(iItemIndex < 0)
		g_iItemBits[iParam1] = 0;
	else
		g_iItemBits[iParam1] ^= (1<<iItemIndex);
	
	ClientCookies_SetCookie(iParam1, CC_TYPE_DONATOR_ITEM_PLAYER_MODELS, g_iItemBits[iParam1]);
	DisplayMenu_ToggleItems(iParam1, GetMenuSelectionPosition());
}

///////////////////////
// DOWNLOAD FILES
///////////////////////
DownloadFileIfNeeded(const String:szFilePath[])
{
	if(!IsFileDownloaded(szFilePath))
		AddToDownloadQueue(szFilePath);
	
	if(!IsFileDownloaded("%s.bz2", szFilePath))
		AddToDownloadQueue("%s.bz2", szFilePath);
}

bool:IsFileDownloaded(const String:szFormat[], any:...)
{
	decl String:szFilePath[PLATFORM_MAX_PATH];
	VFormat(szFilePath, sizeof(szFilePath), szFormat, 2);
	
	if(!FileExists(szFilePath, true))
		return false;
	
	return true;
}

AddToDownloadQueue(const String:szFormat[], any:...)
{
	decl String:szFilePath[PLATFORM_MAX_PATH];
	VFormat(szFilePath, sizeof(szFilePath), szFormat, 2);
	
	new iIndex = FindStringInArray(g_aDownloadQueue, szFilePath);
	if(iIndex != -1)
		return;
	
	PushArrayString(g_aDownloadQueue, szFilePath);
	
	if(GetArraySize(g_aDownloadQueue) == 1)
		StartNextDownloadInQueue();
}

RemoveFromDownloadQueue(const String:szFilePath[])
{
	new iIndex = FindStringInArray(g_aDownloadQueue, szFilePath);
	if(iIndex != -1)
		RemoveFromArray(g_aDownloadQueue, iIndex);
	
	g_bIsFileDownloading = false;
	StartNextDownloadInQueue();
}

StartNextDownloadInQueue()
{
	if(g_bIsFileDownloading)
		return;
	
	if(!GetArraySize(g_aDownloadQueue))
	{
		LogMessage("Files finished downloading for: %s", PLUGIN_NAME);
		return;
	}
	
	decl String:szFilePath[PLATFORM_MAX_PATH];
	GetArrayString(g_aDownloadQueue, 0, szFilePath, sizeof(szFilePath));
	
	LogMessage("Starting download: %s", szFilePath);
	
	g_bIsFileDownloading = true;
	
	decl String:szURL[512];
	FormatEx(szURL, sizeof(szURL), "http://motd.swoobles.com/plugin_files/%s", szFilePath);
	FileDownloader_DownloadFile(szURL, szFilePath, OnDownloadSuccess, OnDownloadFailed);
}

public OnDownloadSuccess(const String:szFilePath[], any:data)
{
	LogMessage("Successfully downloaded: %s", szFilePath);
	RemoveFromDownloadQueue(szFilePath);
}

public OnDownloadFailed(const String:szFilePath[], any:data)
{
	LogError("Failed to downloaded: %s", szFilePath);
	RemoveFromDownloadQueue(szFilePath);
}
