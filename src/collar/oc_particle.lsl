// This file is part of OpenCollar.
// Copyright (c) 2008 - 2017 Lulu Pink, Nandana Singh, Garvin Twine,
// Cleo Collins, Satomi Ahn, Joy Stipe, Wendy Starfall, Romka Swallowtail,
// littlemousy et al.
// Licensed under the GPLv2.  See LICENSE for full details.


// MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
//integer CMD_SAFEWORD = 510;
//integer CMD_RELAY_SAFEWORD = 511;
//integer CMD_BLOCKED = 520;

//integer POPUP_HELP = 1001;
integer NOTIFY = 1002;
//integer SAY = 1004;

integer REBOOT = -1000;

integer LINK_DIALOG = 3;
//integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;

// -- SETTINGS
integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

// -- MENU/DIALOG
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
//integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer LOCKMEISTER = -8888;
integer g_iLMListener;
integer g_iLMListernerDetach;

integer CMD_PARTICLE = 20000;


// --- Menu tokens ---
string UPMENU = "BACK";
string PARENTMENU = "Leash";
string SUBMENU = "Configure";
string L_COLOR = "Color";
string L_GRAVITY = "Gravity";
string L_SIZE = "Size";
string L_FEEL = "Feel";
string L_GLOW = "Shine";
string L_STRICT = "Strict";
string L_TURN = "Turn";
string L_DEFAULTS = "RESET";
string L_CLASSIC_TEX = "Chain"; // Texture name when using the classic particle stream
string L_RIBBON_TEX = "Silk"; // Texture name when using the ribbon_mask particle stream
// Defalut leash particle, can read from defaultsettings:
// leashParticle=Shine~1~ParticleMode~Ribbon~R_Texture~Silk~C_Texture~Chain~Color~<1,1,1>~Size~<0.07,0.07,1.0>~Gravity~-0.7~C_TextureID~keyID~R_TextureID~keyID
list g_lDefaultSettings = [
    L_GLOW, "1",
    L_TURN, "0",
    L_STRICT, "0",
    "ParticleMode", "Ribbon",
    "R_Texture", "Silk",
    "C_Texture", "Chain",
    L_COLOR, "<1.0,1.0,1.0>",
    L_SIZE, "<0.04,0.04,1.0>",
    L_GRAVITY, "-1.0"
];

list g_lSettings = g_lDefaultSettings;

list g_lMenuIDs;
integer g_iMenuStride = 3;
key g_kWearer;

key g_kLeashedTo;
key g_kLeashToPoint;
key g_kParticleTarget;

integer g_bLeashActive;
integer g_bTurnMode;
integer g_bStrictMode;
integer g_iStrictRank;
string g_sParticleMode = "Ribbon"; // Modes can be: Ribbon, Classic and noParticle
string g_sRibbonTexture;
string g_sClassicTexture;
// List of 4 leash/chain points, lockmeister names used (list has to be all lower case, prims dont matter, converting on compare to lower case)
// strided list... LM name, linkNumber, BOOL_ACVTIVE
list g_lLeashPrims;

string g_sSettingToken = "particle_";
//string g_sGlobalToken = "global_";

// Particle system and variables
string g_sParticleTexture = "Silk";
string g_sParticleTextureID; // We need the UUID for llLinkParticleSystem
vector g_vLeashColor = <1.0, 1.0, 1.0>;
vector g_vLeashSize = <0.04, 0.04, 1.0>;
integer g_bParticleGlow = TRUE;
float g_fParticleAge = 3.5;
vector g_vLeashGravity = <0.0,0.0,-1.0>;
integer g_iParticleCount = 1;
float g_fBurstRate = 0.0;
// Same g_lSettings but to store locally the default settings recieved from the defaultsettings note card, using direct string here to save some bits

/*
integer g_bProfiled;
Debug(string sStr) {
    // If you delete the first // from the preceeding and following  lines,
    // profiling is off, debug is off, and the compiler will remind you to
    // remove the debug calls from the code, we're back to production mode
    if (!g_bProfiled) {
        g_bProfiled = TRUE;
        llScriptProfiler(TRUE);
    }
    llOwnerSay(llGetScriptName() + "(min free:" + (string)(llGetMemoryLimit() - llGetSPMaxMemory()) + ")[" + (string)llGetFreeMemory() + "] :\n" + sStr);
}
*/

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenuName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) {
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sMenuName], iIndex, iIndex + g_iMenuStride - 1);
    } else {
        g_lMenuIDs += [kID, kMenuID, sMenuName];
    }
}

FindLinkedPrims() {
    integer iLinkCount = llGetNumberOfPrims();
    integer i;
    // Root prim is 1, so start at 2
    for (i = 2; i <= iLinkCount; i++) {
        string sPrimDesc = (string)llGetObjectDetails(llGetLinkKey(i), [OBJECT_DESC]);
        list lTemp = llParseString2List(sPrimDesc, ["~"], []);
        integer j;
        for (; j < llGetListLength(lTemp); j++) {
            string sTest = llList2String(lTemp, j);
            //Debug(sTest);
            // Expected either "leashpoint" or "leashpoint:point"
            if (llGetSubString(sTest, 0, 9) == "leashpoint") {
                if (llGetSubString(sTest, 11, -1) == "") {
                    g_lLeashPrims += [sTest, (string)i, "1"];
                } else {
                    g_lLeashPrims += [llGetSubString(sTest, 11, -1), (string)i, "1"];
                }
            }
        }
    }

    if (g_lLeashPrims) {
        llMessageLinked(LINK_ROOT, LM_SETTING_RESPONSE, "leashpoint=" + llList2String(g_lLeashPrims, 1), "");
    } else {
        // If we did not find any leashpoint... we unset the root as one
        g_lLeashPrims = ["collar", LINK_THIS, "1"];
    }
}

Particles(integer iLink, key kParticleTarget) {
    // When we have no target to send particles to, dont create any
    if (kParticleTarget == NULL_KEY) {
        return;
    }

    integer iFlags = PSYS_PART_FOLLOW_VELOCITY_MASK | PSYS_PART_TARGET_POS_MASK | PSYS_PART_FOLLOW_SRC_MASK;

    if (g_sParticleMode == "Ribbon") {
        iFlags = iFlags | PSYS_PART_RIBBON_MASK;
    }

    if (g_bParticleGlow) {
        iFlags = iFlags | PSYS_PART_EMISSIVE_MASK;
    }

    list lTemp = [
        PSYS_PART_MAX_AGE, g_fParticleAge,
        PSYS_PART_FLAGS, iFlags,
        PSYS_PART_START_COLOR, g_vLeashColor,
        //PSYS_PART_END_COLOR, g_vLeashColor,
        PSYS_PART_START_SCALE, g_vLeashSize,
        //PSYS_PART_END_SCALE, g_vLeashSize,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_DROP,
        PSYS_SRC_BURST_RATE, g_fBurstRate,
        PSYS_SRC_ACCEL, g_vLeashGravity,
        PSYS_SRC_BURST_PART_COUNT, g_iParticleCount,
        //PSYS_SRC_BURST_SPEED_MIN, fMinSpeed,
        //PSYS_SRC_BURST_SPEED_MAX, fMaxSpeed,
        PSYS_SRC_TARGET_KEY, kParticleTarget,
        PSYS_SRC_MAX_AGE, 0,
        PSYS_SRC_TEXTURE, g_sParticleTextureID
    ];
    llLinkParticleSystem(iLink, lTemp);
}

StartParticles(key kParticleTarget) {
    //Debug(llList2CSV(g_lLeashPrims));
    StopParticles(FALSE);

    integer i;
    for (; i < llGetListLength(g_lLeashPrims); i += 3) {
        if ((integer)llList2String(g_lLeashPrims, i + 2)) {
            Particles((integer)llList2String(g_lLeashPrims, i + 1), kParticleTarget);
            /*
            if (g_sParticleMode == "Classic") {
                i += 3;
            }
            */
        }
    }

    g_bLeashActive = TRUE;
}

StopParticles(integer iEnd) {
    integer i;
    for (; i < llGetListLength(g_lLeashPrims); i++) {
        llLinkParticleSystem((integer)llList2String(g_lLeashPrims, i + 1), []);
    }

    if (iEnd) {
        g_bLeashActive = FALSE;
        g_kLeashedTo = NULL_KEY;
        g_kLeashToPoint = NULL_KEY;
        g_kParticleTarget = NULL_KEY;
        llSetTimerEvent(0.0);
        //llSensorRemove();
    }
}

SaveSettings(string sToken, string sValue, integer bSaveToLocal) {
    integer iIndex = llListFindList(g_lSettings, [sToken]);
    if (iIndex >= 0) {
        g_lSettings = llListReplaceList(g_lSettings, [sValue], iIndex + 1, iIndex + 1);
    } else {
        g_lSettings += [sToken, sValue];
    }

    if (sToken == "R_Texture") {
        if (llToLower(llGetSubString(sValue, 0, 6)) == "!ribbon") {
            L_RIBBON_TEX = llGetSubString(sValue, 8, -1);
        } else {
            L_RIBBON_TEX = sValue;
        }
    } else if (sToken == "C_Texture") {
        if (llToLower(llGetSubString(sValue, 0, 7)) == "!classic") {
            L_CLASSIC_TEX = llGetSubString(sValue, 9, -1);
        } else {
            L_CLASSIC_TEX = sValue;
        }
    }

    if (bSaveToLocal) {
        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + sToken + "=" + sValue, "");
    }
}

string GetDefaultSetting(string sToken) {
    integer iIndex = llListFindList(g_lDefaultSettings, [sToken]);
    if (~iIndex) {
        return llList2String(g_lDefaultSettings, iIndex + 1);
    }
    return "";
}

string GetSetting(string sToken) {
    integer iIndex = llListFindList(g_lSettings, [sToken]);
    if (~iIndex) {
        return llList2String(g_lSettings, iIndex + 1);
    }
    return GetDefaultSetting(sToken); // Return from defaultsettings if not present
}

// Get settings before StartParticles
GetSettings(integer bStartParticles) {
    // Debug("settings: "+llList2CSV(g_lSettings));
    g_sParticleMode = GetSetting("ParticleMode");
    g_sClassicTexture = GetSetting("C_Texture");
    g_sRibbonTexture = GetSetting("R_Texture");
    g_vLeashSize = (vector)GetSetting(L_SIZE);
    g_vLeashColor = (vector)GetSetting(L_COLOR);
    g_vLeashGravity.z = (float)GetSetting(L_GRAVITY);
    g_bParticleGlow = (integer)GetSetting(L_GLOW);

    if (g_sParticleMode == "Classic") {
        SetTexture(g_sClassicTexture, NULL_KEY);
    } else if (g_sParticleMode == "Ribbon") {
        SetTexture(g_sRibbonTexture, NULL_KEY);
    }

    if (bStartParticles && g_kLeashedTo != NULL_KEY){
        llSleep(0.1);
        StartParticles(g_kParticleTarget);
    }
}

// Added bSave as a boolean, to make this a more versatile wrapper
SetTexture(string sIn, key kIn) {
    g_sParticleTexture = sIn;
    if (sIn == "Silk") {
        g_sParticleTextureID = "cdb7025a-9283-17d9-8d20-cee010f36e90";
    } else if (sIn == "Chain") {
        g_sParticleTextureID = "4cde01ac-4279-2742-71e1-47ff81cc3529";
    } else if (sIn == "Leather") {
        g_sParticleTextureID = "8f4c3616-46a4-1ed6-37dc-9705b754b7f1";
    } else if (sIn == "Rope") {
        g_sParticleTextureID = "9a342cda-d62a-ae1f-fc32-a77a24a85d73";
    } else if (sIn == "totallytransparent") {
        g_sParticleTextureID = TEXTURE_TRANSPARENT;
    } else {
        if (llToLower(g_sParticleTexture) == "noleash") {
            g_sParticleMode = "noParticle";
        }
        //Debug("particleTexture= " + sIn);
        g_sParticleTextureID = llGetInventoryKey(g_sParticleTexture);
        if (g_sParticleTextureID == NULL_KEY) {
            g_sParticleTextureID = sIn; //for textures without full perm, we send the texture name. For this to work, texture must be in the emitter prim as well as in root, if different.
        }
    }

    if (g_sParticleMode == "Ribbon") {
        if (llToLower(llGetSubString(sIn, 0, 6)) == "!ribbon") {
            L_RIBBON_TEX = llGetSubString(sIn, 8, -1);
        } else {
            L_RIBBON_TEX = sIn;
        }

        if (GetSetting("R_TextureID")) {
            g_sParticleTextureID = GetSetting("R_TextureID");
        }

        if (kIn) {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Leash texture set to " + L_RIBBON_TEX, kIn);
        }
    } else if (g_sParticleMode == "Classic") {
        if (llToLower(llGetSubString(sIn, 0, 7)) == "!classic") {
            L_CLASSIC_TEX = llGetSubString(sIn, 9, -1);
        } else {
            L_CLASSIC_TEX = sIn;
        }

        if (GetSetting("C_TextureID")) {
            g_sParticleTextureID = GetSetting("C_TextureID");
        }

        if (kIn) {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Leash texture set to " + L_CLASSIC_TEX, kIn);
        }
    } else if (kIn) {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Leash texture set to " + g_sParticleTexture, kIn);
    }

    //Debug("particleTextureID= " + (string)g_sParticleTextureID);
    //Debug("activeleashpoints= " + (string)g_bLeashActive);
    if (g_bLeashActive) {
        if (g_sParticleMode == "noParticle") {
            StopParticles(FALSE);
        } else {
            StartParticles(g_kParticleTarget);
        }
    }
}

// Menus

string Checkbox(integer iValue, string sLabel) {
    if (iValue) return "☑ " + sLabel;
    else return "☐ " + sLabel;
}

ConfigureMenu(key kIn, integer iAuth) {
    list lButtons = [
        Checkbox(g_bParticleGlow, "Shine"),
        Checkbox(g_bTurnMode, "Turn"),
        Checkbox(g_bStrictMode, "Strict")
    ];

    if (g_sParticleMode == "Ribbon") {
        lButtons += ["☐ " + L_CLASSIC_TEX, "☒ " + L_RIBBON_TEX, "☐ Invisible"];
    } else if (g_sParticleMode == "noParticle") {
        lButtons += ["☐ " + L_CLASSIC_TEX, "☐ " + L_RIBBON_TEX, "☒ Invisible"];
    } else if (g_sParticleMode == "Classic") {
        lButtons += ["☒ " + L_CLASSIC_TEX, "☐ " + L_RIBBON_TEX, "☐ Invisible"];
    }

    lButtons += [L_FEEL, L_COLOR];

    string sPrompt = "\n[Leash Configuration]\n\nCustomize the looks and feel of your leash.";
    Dialog(kIn, sPrompt, lButtons, [UPMENU], 0, iAuth, "configure");
}

FeelMenu(key kIn, integer iAuth) {
    list lButtons = ["Bigger", "Smaller", L_DEFAULTS, "Heavier", "Lighter"];
    string sPrompt = "\nHere you can change the weight and size of your leash.";
    Dialog(kIn, sPrompt, lButtons, [UPMENU], 0, iAuth, "feel");
}

ColorMenu(key kIn, integer iAuth) {
    string sPrompt = "\nChoose a color.";
    Dialog(kIn, sPrompt, ["colormenu please"], [UPMENU], 0, iAuth, "color");
}

LMSay() {
    llShout(LOCKMEISTER, (string)llGetOwnerKey(g_kLeashedTo) + "collar");
    llShout(LOCKMEISTER, (string)llGetOwnerKey(g_kLeashedTo) + "handle");
    llSetTimerEvent(4.0);
}

default {
    on_rez(integer iRez) {
        llResetScript();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        FindLinkedPrims();
        StopParticles(TRUE);
        GetSettings(FALSE);
        //Debug("Starting");
    }

    link_message(integer iSender, integer iNum, string sMessage, key kMessageID) {
        if (iNum == CMD_PARTICLE) {
            g_kLeashedTo = kMessageID;
            if (sMessage == "unleash") {
                StopParticles(TRUE);
                llListenRemove(g_iLMListener);
                llListenRemove(g_iLMListernerDetach);
            } else {
                //Debug("leash active");
                if (g_sParticleMode != "noParticle") {
                    integer bLeasherIsAv = (integer)llList2String(llParseString2List(sMessage, ["|"], [""]), 1);
                    g_kParticleTarget = g_kLeashedTo;
                    StartParticles(g_kParticleTarget);
                    if (bLeasherIsAv) {
                        llListenRemove(g_iLMListener);
                        llListenRemove(g_iLMListernerDetach);
                        if (llGetSubString(sMessage, 0, 10)  == "leashhandle") {
                            g_iLMListener = llListen(LOCKMEISTER, "", "", (string)g_kLeashedTo + "handle ok");
                            g_iLMListernerDetach = llListen(LOCKMEISTER, "", "", (string)g_kLeashedTo + "handle detached");
                        } else {
                            g_iLMListener = llListen(LOCKMEISTER, "", "", "");
                        }
                        LMSay();
                    }
                }
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            if (llToLower(sMessage) == "leash configure") {
                if (iNum <= CMD_TRUSTED || iNum == CMD_WEARER) {
                    ConfigureMenu(kMessageID, iNum);
                } else {
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "%NOACCESS%", kMessageID);
                }
            } else if (sMessage == "menu " + SUBMENU) {
                if (iNum <= CMD_TRUSTED || iNum == CMD_WEARER) {
                    ConfigureMenu(kMessageID, iNum);
                } else {
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "%NOACCESS%", kMessageID);
                    llMessageLinked(LINK_THIS, iNum, "menu " + PARENTMENU, kMessageID);
                }
            } else if (llToLower(sMessage) == "particle reset") {
                g_lSettings = []; // Clear current settings
                if (kMessageID) {
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Leash-settings restored to %DEVICETYPE% defaults.", kMessageID);
                }
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "all", "");
                GetSettings(TRUE);
            } else if (llToLower(sMessage) == "theme particle sent") {
                GetSettings(TRUE);
            }
        } else if (iNum == MENUNAME_REQUEST && sMessage == PARENTMENU) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, PARENTMENU + "|" + SUBMENU, "");
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            if (~iMenuIndex) {
                //Debug("Current menu:" + g_sCurrentMenu);
                list lMenuParams = llParseString2List(sMessage, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sButton = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);

                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

                if (sButton == UPMENU) {
                    if(sMenu == "configure") {
                        llMessageLinked(LINK_THIS, iAuth, "menu " + PARENTMENU, kAv);
                    } else {
                        ConfigureMenu(kAv, iAuth);
                    }
                } else  if (sMenu == "configure") {
                    string sButtonType = llGetSubString(sButton, 2, -1);
                    string sButtonCheck = llGetSubString(sButton, 0, 0);
                    if (sButton == L_COLOR) {
                        ColorMenu(kAv, iAuth);
                        return;
                    } else if (sButton == "Feel") {
                        FeelMenu(kAv, iAuth);
                        return;
                    } else if(sButtonType == L_GLOW) {
                        g_bParticleGlow = sButtonCheck == "☐";
                        SaveSettings(sButtonType, (string)g_bParticleGlow, TRUE);
                    } else if(sButtonType == L_TURN) {
                        g_bTurnMode = sButtonCheck == "☐";
                        if (g_bTurnMode) {
                            llMessageLinked(LINK_THIS, iAuth, "turn on", kAv);
                        } else {
                            llMessageLinked(LINK_THIS, iAuth, "turn off", kAv);
                        }
                    } else if(sButtonType == L_STRICT) {
                        if (sButtonCheck == "☐") {
                            g_bStrictMode = TRUE;
                            g_iStrictRank = iAuth;
                            llMessageLinked(LINK_THIS, iAuth, "strict on", kAv);
                        } else if (iAuth <= g_iStrictRank) {
                            g_bStrictMode = FALSE;
                            g_iStrictRank = iAuth;
                            llMessageLinked(LINK_THIS, iAuth, "strict off", kAv);
                        } else {
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "%NOACCESS%", kAv);
                        }
                    } else if(sButtonType == L_RIBBON_TEX) {
                        if (sButtonCheck == "☐") {
                            g_sParticleMode = "Ribbon";
                            SetTexture(g_sRibbonTexture, kAv);
                            SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        } else {
                            g_sParticleMode = "Classic";
                            SetTexture(g_sClassicTexture, kAv);
                            SaveSettings("C_Texture", g_sClassicTexture, TRUE);
                        }

                        SaveSettings("ParticleMode", g_sParticleMode, TRUE);
                    } else if(sButtonType == L_CLASSIC_TEX) {
                        if (sButtonCheck == "☐") {
                            g_sParticleMode = "Classic";
                            SetTexture(g_sClassicTexture, kAv);
                            SaveSettings("C_Texture", g_sClassicTexture, TRUE);
                        } else {
                            g_sParticleMode = "Ribbon";
                            SetTexture(g_sRibbonTexture, kAv);
                            SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        }

                        SaveSettings("ParticleMode", g_sParticleMode, TRUE);
                    } else if(sButtonType == "Invisible") {
                        if (sButtonCheck == "☐") {
                            g_sParticleMode = "noParticle";
                            g_sParticleTexture = "noleash";
                            SetTexture("noleash", kAv);
                        } else {
                            g_sParticleMode = "Ribbon";
                            SetTexture(g_sRibbonTexture, kAv);
                            SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        }

                        SaveSettings("ParticleMode", g_sParticleMode, TRUE);
                    }

                    if (g_sParticleMode != "noParticle" && g_bLeashActive) {
                        StartParticles(g_kParticleTarget);
                    } else if (g_bLeashActive) {
                        StopParticles(FALSE);
                    } else {
                        StopParticles(TRUE);
                    }

                    ConfigureMenu(kAv, iAuth);
                } else if (sMenu == "color") {
                    g_vLeashColor = (vector)sButton;
                    SaveSettings(L_COLOR, sButton, TRUE);

                    if (g_sParticleMode != "noParticle" && g_bLeashActive) {
                        StartParticles(g_kParticleTarget);
                    }

                    ColorMenu(kAv, iAuth);
                } else if (sMenu == "feel") {
                    if (sButton == L_DEFAULTS) {
                        if (g_sParticleMode == "Ribbon") {
                            g_vLeashSize = (vector)GetDefaultSetting(L_SIZE);
                        } else {
                            g_vLeashSize = (vector)GetDefaultSetting(L_SIZE) + <0.03, 0.03, 0.0>;
                        }
                        g_vLeashGravity.z = (float)GetDefaultSetting(L_GRAVITY);
                    } else if (sButton == "Bigger") {
                        g_vLeashSize.x += 0.03;
                        g_vLeashSize.y += 0.03;
                    } else if (sButton == "Smaller") {
                        g_vLeashSize.x -= 0.03;
                        g_vLeashSize.y -= 0.03;

                        if (g_vLeashSize.x < 0.04 && g_vLeashSize.y < 0.04) {
                            g_vLeashSize.x = 0.04;
                            g_vLeashSize.y = 0.04;
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "The leash won't get much smaller.", kAv);
                        }
                    } else if (sButton == "Heavier") {
                        g_vLeashGravity.z -= 0.1;

                        if (g_vLeashGravity.z < -3.0) {
                            g_vLeashGravity.z = -3.0;
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "That's the heaviest it can be.", kAv);
                        }
                    } else if (sButton == "Lighter") {
                        g_vLeashGravity.z += 0.1;

                        if (g_vLeashGravity.z > 0.0) {
                            g_vLeashGravity.z = 0.0;
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "It can't get any lighter now.", kAv);
                        }
                    }

                    SaveSettings(L_GRAVITY, (string)g_vLeashGravity.z, TRUE);
                    SaveSettings(L_SIZE, (string)g_vLeashSize, TRUE);

                    if (g_sParticleMode != "noParticle" && g_bLeashActive) {
                        StartParticles(g_kParticleTarget);
                    }

                    FeelMenu(kAv, iAuth);
                }
                //} else {
                //Debug("Not our menu");
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LM_SETTING_RESPONSE) {
            // Debug ("LocalSettingsResponse: " + sMessage);
            integer i = llSubStringIndex(sMessage, "=");
            string sToken = llGetSubString(sMessage, 0, i - 1);
            string sValue = llGetSubString(sMessage, i + 1, -1);

            i = llSubStringIndex(sToken, "_");

            if (sToken == "leash_leashedto") {
                g_kLeashedTo = (key)llList2String(llParseString2List(sValue, [","], []), 0);
            } else if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                // Load current settings
                //Debug("Setting Response. " + sToken + sValue);
                sToken = llGetSubString(sToken, i + 1, -1);
                SaveSettings(sToken, sValue, FALSE);
            } else if (llGetSubString(sToken, 0, i) == "leash_") {
                sToken = llGetSubString(sToken, i + 1, -1);
                //Debug(sToken + sValue);
                if (sToken == "strict") {
                    // Debug((string)iAuth);
                    g_bStrictMode = (integer)llGetSubString(sValue, 0, 0);
                    g_iStrictRank = (integer)llGetSubString(sValue, 2, -1);
                } else if (sToken == "turn") {
                    g_bTurnMode = (integer)sValue;
                }
            } else if (sMessage == "settings=sent" || sMessage == "theme particle sent") {
                // In case wearer is currently leashed
                GetSettings(TRUE);
            }
            /*
            else if (sToken == "strictAuthError") {
                g_bStrictMode = TRUE;
                ConfigureMenu(kMessageID, (integer)sValue);
            }
            */
        } else if (iNum == LINK_UPDATE) {
            if (sMessage == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sMessage == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sMessage == "reboot") {
            llResetScript();
        }
        /*
        else if (iNum == LM_SETTING_DELETE) {
            if (sMessage == "leash_leashedto") {
                StopParticles(TRUE);
            }
        }
        */
    }

    timer() {
        if (llGetOwnerKey(g_kParticleTarget) == g_kParticleTarget) {
            if(g_kLeashedTo) {
                llRegionSayTo(g_kLeashedTo, LOCKMEISTER, (string)g_kLeashedTo + "|LMV2|RequestPoint|collar");
                g_kParticleTarget = g_kLeashedTo;
                StartParticles(g_kParticleTarget);
            } else if(!g_bLeashActive) {
                llSetTimerEvent(0.0);
            }
        }
    }

    listen(integer iChannel, string sName, key kID, string sMessage) {
        if (iChannel == LOCKMEISTER) {
            // Leash holder announced it got detached... send particles to avi
            if (sMessage == (string)g_kLeashedTo + "handle detached") {
                g_kParticleTarget = g_kLeashedTo;
                StartParticles(g_kParticleTarget);
                llRegionSayTo(g_kLeashedTo, LOCKMEISTER, (string)g_kLeashedTo + "|LMV2|RequestPoint|collar");
            }
            // We heard from a leash holder. re-direct particles
            if (llGetOwnerKey(kID) == g_kLeashedTo) {
                if (llGetSubString(sMessage, -2, -1) == "ok") { // It's an old style v1 LM reply
                    sMessage = llGetSubString(sMessage, 36, -1);
                    if (sMessage == "collar ok") {
                        g_kParticleTarget = kID;
                        StartParticles(g_kParticleTarget);
                        llRegionSayTo(g_kLeashedTo, LOCKMEISTER, (string)g_kLeashedTo + "|LMV2|RequestPoint|collar");
                    }

                    if (sMessage == "handle ok") {
                        g_kParticleTarget = kID;
                        StartParticles(g_kParticleTarget);
                        //llSetTimerEvent(0.0);
                    }
                }  else { // v2 style LM reply
                    list lTemp = llParseString2List(sMessage, ["|"], [""]);
                    // lTemp should look like [g_kLeashto,"LMV2","ReplyPoint","handle",g_kParticleTarget]
                    // is it a v2 style LM reply?
                    if(llList2String(lTemp, 1) == "LMV2" && llList2String(lTemp, 2) == "ReplyPoint") {
                        g_kParticleTarget = (key)llList2String(lTemp, 4);
                        StartParticles(g_kParticleTarget);
                    }
                }
            }
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_INVENTORY) {
            integer iNumberOfTextures = llGetInventoryNumber(INVENTORY_TEXTURE);
            integer iLeashTexture;
            if (iNumberOfTextures) {
                integer i;
                for (; i < iNumberOfTextures; ++i) {
                    string sName = llGetInventoryName(INVENTORY_TEXTURE, i);
                    if (llToLower(llGetSubString(sName,0,6)) == "!ribbon") {
                        g_sRibbonTexture = sName;
                        L_RIBBON_TEX = llGetSubString(g_sRibbonTexture, 8, -1);
                        SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        iLeashTexture += 1;
                    } else if (llToLower(llGetSubString(sName, 0, 7)) == "!classic") {
                        g_sClassicTexture = sName;
                        L_CLASSIC_TEX = llGetSubString(g_sClassicTexture, 9, -1);
                        SaveSettings("C_Texture", g_sClassicTexture, TRUE);
                        iLeashTexture += 2;
                    }
                }
            }

            if (!iLeashTexture) {
                if (llSubStringIndex(GetSetting("C_Texture"), "!") == 0) {
                    SaveSettings("C_Texture", "Chain", TRUE);
                }

                if (llSubStringIndex(GetSetting("R_Texture"), "!") == 0) {
                    SaveSettings("R_Texture", "Silk", TRUE);
                }
            } else if (iLeashTexture == 1) {
                if (llSubStringIndex(GetSetting("C_Texture"), "!") == 0) {
                    SaveSettings("C_Texture", "Chain", TRUE);
                }
            } else if (iLeashTexture == 2) {
                if (llSubStringIndex(GetSetting("R_Texture"), "!") == 0) {
                    SaveSettings("R_Texture", "Silk", TRUE);
                }
            }
            //GetSettings(TRUE);
        }

        /*
        if (iChange & CHANGED_REGION) {
            if (g_bProfiled) {
                llScriptProfiler(TRUE);
                Debug("profiling restarted");
            }
        }
        */
    }
}
