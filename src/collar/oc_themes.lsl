// This file is part of OpenCollar.
// Copyright (c) 2008 - 2017 Nandana Singh, Lulu Pink, Garvin Twine,
// Cleo Collins, Master Starship, Joy Stipe, Wendy Starfall, littlemousy,
// Romka Swallowtail et al.
// 2018 Restless Swords added (optional) support for faces=n and/or specular=xxxx and/or normal=yyyy
// Licensed under the GPLv2.  See LICENSE for full details.


// Based on a merge of all OpenCollar appearance plugins by littlemousy
// Virtual Disgrace - Paint is derivate of Virtual Disgrace - Customize
// OpenCollar - styles is derivative of Virtual Disgrace - Paint

list g_lElements; // List of element types, built on script start.  Changed event restarts script on link set change
list g_lElementFlags;
list g_lTextureDefaults; // Default textures for each element, actually the last textures sent out by the settings script, so not so much "default settings", closer to "what wa set when worn"
list g_lShinyDefaults;
list g_lHideDefaults;
list g_lColorDefaults;

string g_sDeviceType = "collar";

list g_lTextures; // Stores names of all textures in collar and notecard
list g_lTextureShortNames; // Stores names of all textures in collar and notecard
list g_lTextureKeys; // Stores keys of notecard textures, and names of textures in collar, indexed by the names in g_lTextures
integer g_iTextureFace;
string g_sNormalMap;
string g_sSpecularMap;
integer g_iTexturesNotecardLine; // Current number in notecard read
key g_kTextureCardUUID; // UUID of textures notecard, used to determine when it changed so it can be re-read only when needed
string g_sTextureCard; // Stores name of current textures card.  Might be "textures" or ="textures_custom", set in BuildTexturesList()
key g_kTexturesNotecardRead; // Key of the dataserver request for notecard read
string g_sCurrentTheme;
integer g_bThemesReady;

list g_lMenuIDs; // Menu information
integer g_iMenuStride = 3;

// MESSAGE MAP
//integer CMD_ZERO           = 0;
integer CMD_OWNER          = 500;
//integer CMD_TRUSTED        = 501;
//integer CMD_GROUP          = 502;
integer CMD_WEARER         = 503;
//integer CMD_EVERYONE       = 504;
//integer CMD_RLV_RELAY      = 507;
//integer CMD_SAFEWORD       = 510;
//integer CMD_RELAY_SAFEWORD = 511;
//integer CMD_BLOCKED        = 520;

integer LM_SETTING_SAVE     = 2000;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE   = 2003;

integer NOTIFY = 1002;
//integer SAY    = 1004;

integer REBOOT = -1000;

integer LINK_DIALOG = 3;
//integer LINK_RLV    = 4;
integer LINK_SAVE   = 5;
integer LINK_UPDATE = -10;

//integer MENUNAME_REQUEST  = 3000;
//integer MENUNAME_RESPONSE = 3001;

integer DIALOG          = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT  = -9002;

//integer TOUCH_REQUEST  = -9500;
//integer TOUCH_CANCEL   = -9501;
integer TOUCH_RESPONSE = -9502;
//integer TOUCH_EXPIRE   = -9503;

key g_kWearer;

list g_lShiny = ["none", "low", "medium", "high", "specular"];
list g_lGlows;
list g_lGlow = [
  "none", 0.0,
  "low", 0.1,
  "medium", 0.2,
  "high", 0.4,
  "veryHigh", 0.8
];
integer g_iNumHideableElements;
integer g_iNumElements;
integer g_bCollarHidden;
string g_sThemesCard = ".themes";
key g_kThemesNotecardRead;
key g_kThemesCardUUID;
integer g_iSetThemeAuth;
key g_kSetThemeUser;
string g_sThemesNotecardReadType;
list g_lThemes;
integer g_iThemesNotecardLine;
integer g_bLeashParticle;
integer g_bLooks;

//command list - used for check in UserCommand()
list g_lCommands = ["themes", "hide", "show", "stealth", "color", "texture", "shiny", "glow", "looks", "normal", "specular"];

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

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
  key kMenuID = llGenerateKey();
  llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

  integer iIndex = llListFindList(g_lMenuIDs, [kID]);
  if (~iIndex) {
    g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
  } else {
    g_lMenuIDs += [kID, kMenuID, sName];
  }
}

LooksMenu(key kID, integer iAuth) {
  Dialog(kID, "\nHere you can change cosmetic settings of the %DEVICETYPE%. \"Themes\" will also be applied to any matching cuffs.", ["Color", "Glow", "Shiny", "Texture", "Themes"], ["BACK"], 0, iAuth, "LooksMenu~menu");
}

ThemeMenu(key kID, integer iAuth) {
  list lButtons;
  integer i;
  integer iLength = llGetListLength(g_lThemes);
  for (; i < iLength; i += 2) {
    lButtons += llList2List(g_lThemes, i, i);
  }
  Dialog(kID, "\n[Themes]\n\nChoose a visual theme for your %DEVICETYPE%.\n", lButtons, ["BACK"], 0, iAuth, "ThemeMenu~themes");
}

ShinyMenu(key kID, integer iAuth, string sElement) {
  string sShineElement = llList2String(llParseString2List(sElement, [" "], []), -1);
  Dialog(kID, "\nSelect a degree of shine for " + sShineElement + ".", g_lShiny, ["BACK"], 0, iAuth, "ShinyMenu~" + sElement);
}

GlowMenu(key kID, integer iAuth, string sElement) {
  string sGlowElement = llList2String(llParseString2List(sElement,[" "], []), -1);
  list lButtons = llList2ListStrided(g_lGlow, 0, -1, 2);
  Dialog(kID, "\nSelect a degree of glow for " + sGlowElement + ".", lButtons, ["BACK"], 0, iAuth, "GlowMenu~" + sElement);
}

TextubRemenu(key kID, integer iPage, integer iAuth, string sElement) {
  list lElementTextures;
  integer bCustomTextureFound;
  string sTexElement = llList2String(llParseString2List(sElement, [" "], []), -1);
  integer iNumTextures = llGetListLength(g_lTextures);
  while (iNumTextures--) {
    string sTextureName = llList2String(g_lTextures, iNumTextures);
    if (!~llListFindList(lElementTextures, [sTextureName])) { // We can ignore textures we already know about
      if (llSubStringIndex(sTextureName, sTexElement + "~") == 0) { // A texture starting with sElement~ is just for me. Add it
        lElementTextures += llList2String(g_lTextureShortNames, iNumTextures);
        if ((!bCustomTextureFound) && llGetListLength(lElementTextures)) {  //this is the first custom texture we found, we don't want general textures.  Clear thelist and start again
          bCustomTextureFound = TRUE;
          lElementTextures = [];
          iNumTextures = llGetListLength(g_lTextures);
        }
      } else if (!~llSubStringIndex(sTextureName, "~") && !bCustomTextureFound) { // A texture with no ~ in it is a general texture. Add it unless we have custom textures
        lElementTextures += llList2String(g_lTextureShortNames, iNumTextures);
      }
    }
  }

  Dialog(kID, "\nSelect a texture to apply to " + sTexElement + ".", llListSort(lElementTextures, 1, TRUE), ["BACK"], iPage, iAuth, "TextubRemenu~" + sElement);
}

ColorMenu(key kID, integer iPage, integer iAuth, string sBreadcrumbs) {
  string sCategory = llList2String(llParseString2List(sBreadcrumbs, [" "], []), -1);
  Dialog(kID, "\nSelect a color for " + sCategory + ".", ["colormenu please"], ["BACK"], iPage, iAuth, "ColorMenu~" + sBreadcrumbs);
}

ElementMenu(key kAv, integer iPage, integer iAuth, string sType) {
  integer iMask;
  string sTypeNice;
  sType = llToLower(sType);
  if (sType == "texture") {
    iMask = 1;
    sTypeNice = "Texture";
  } else if (sType == "color") {
    iMask = 2;
    sTypeNice = "Color";
  } else if (sType == "shiny") {
    iMask = 4;
    sTypeNice = "Shininess";
  } else if (sType == "glow") {
    iMask = 8;
    sTypeNice = "Glow";
  }

  string sPrompt = "\nSelect an element to adjust its " + sTypeNice + ".";
  list lButtons;
  integer numElements = g_iNumElements;
  while (numElements--) {
    if (~llList2Integer(g_lElementFlags, numElements) & iMask) { // If the flags fit the mask
      string sElement = llList2String(g_lElements, numElements);
      lButtons += sElement;
    }
  }
  lButtons = llListSort(lButtons, 1, TRUE);
  Dialog(kAv, sPrompt, lButtons, ["ALL", "BACK"], iPage, iAuth, "ElementMenu~" + sType);
}

string LinkType(integer iLinkNum, string sSearchString) {
  string sDesc = llList2String(llGetLinkPrimitiveParams(iLinkNum, [PRIM_DESC]), 0);
  // Prim desc will be elementtype~notexture(maybe)
  list lParams = llParseString2List(llStringTrim(sDesc, STRING_TRIM), ["~"], []);

  if (~llListFindList(lParams, [sSearchString])) {
    return "immutable";
  } else if (sDesc == "" || sDesc == "(No Description)") {
    return "";
  } else {
    return llList2String(lParams, 0);
  }
}

BuildThemesList() {
  if (llGetInventoryType(g_sThemesCard) == INVENTORY_NOTECARD) {
    g_kThemesCardUUID = llGetInventoryKey(g_sThemesCard);
    g_lThemes = [];
    g_iThemesNotecardLine = 0;
    g_sThemesNotecardReadType = "initialize";
    g_kThemesNotecardRead = llGetNotecardLine(g_sThemesCard, g_iThemesNotecardLine);
  //} else {
  //  Debug("No themes card:" + g_sThemesCard);
  }
}

BuildTexturesList() {
  g_lTextures = [];
  g_lTextureKeys = [];
  g_lTextureShortNames = [];
  // First add textures in the collar
  integer numInventoryTextures = llGetInventoryNumber(INVENTORY_TEXTURE);
  while (numInventoryTextures--) {
    string sTextureName = llGetInventoryName(INVENTORY_TEXTURE, numInventoryTextures);
    string sShortName=llList2String(llParseString2List(sTextureName, ["~"], []), -1);
    if (!(llGetSubString(sTextureName, 0, 5) == "leash_" || sTextureName == "chain" || sTextureName == "rope")) { // We want to ignore particle textures, and textures named in the notecard
      /*
      if (llStringLength(sShortName) > 23) {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Texture name " + sTextureName + " in %DEVICETYPE% is too long, dropping.", g_kWearer);
      else {
      */
      g_lTextures += sTextureName;
      g_lTextureKeys += sTextureName; // Add name of texture inside collar as the key, to match notecard lists format
      g_lTextureShortNames+=sShortName;
      //}
    }
  }

  // After inventory, start reading textures notecard
  g_sTextureCard = "!textures";
  if (llGetInventoryType(g_sTextureCard) != INVENTORY_NOTECARD) {
    g_sTextureCard = ".textures";
  }
  if (llGetInventoryType(g_sTextureCard) == INVENTORY_NOTECARD) {
    g_iTexturesNotecardLine = 0;
    g_kTextureCardUUID = llGetInventoryKey(g_sTextureCard);
    g_kTexturesNotecardRead = llGetNotecardLine(g_sTextureCard, g_iTexturesNotecardLine);
  } else {
    g_kTextureCardUUID = NULL_KEY;
  }
}

BuildElementsList() {
  g_iNumHideableElements = 0;
  g_iNumElements = 0;
  // Loop through non-root prims, build element list
  integer iLinkNum = llGetNumberOfPrims() + 1;
  while (iLinkNum-- > 2) { // Root prim is 1, so stop at 2
    string sElement = llList2String(llGetLinkPrimitiveParams(iLinkNum, [PRIM_DESC]), 0);
    if (~llSubStringIndex(llToLower(sElement), "floattext") || ~llSubStringIndex(llToLower(sElement), "leashpoint")) {
      // Do nothing, these are alwasys no-anything
    } else if (sElement != "" && sElement != "(No Description)") { // Element has a description, so parse it
      //prim desc will be elementtype~notexture(maybe)
      list lParams = llParseString2List(llStringTrim(sElement, STRING_TRIM), ["~"], []);
      string sElementName = llList2String(lParams, 0);
      integer iLinkFlags = 0; // Bitmask. 1 = notexture, 2 = nocolor, 4 = noshiny, 8 = noglow, 16 = nohide
      if (~llListFindList(lParams, ["notexture"])) iLinkFlags = iLinkFlags | 1;
      if (~llListFindList(lParams, ["nocolor"])) iLinkFlags = iLinkFlags | 2;
      if (~llListFindList(lParams, ["noshiny"])) iLinkFlags = iLinkFlags | 4;
      if (~llListFindList(lParams, ["noglow"])) iLinkFlags = iLinkFlags | 8;
      if (~llListFindList(lParams, ["nohide"])) iLinkFlags = iLinkFlags | 16;

      integer iElementIndex = llListFindList(g_lElements, [sElementName]);
      if (!~iElementIndex) { // It's a new element, store it, and its flags, and a default texture
        g_lElements += sElementName;
        g_lElementFlags += iLinkFlags;
        if (!(iLinkFlags & 16)) {
          g_iNumHideableElements++;
        }
        g_iNumElements++;
      } else { // We already know this element, so "bitwise not" its flags with the new one.  if any element of a type is e.g. texturable, notextures bit should be 0 so it shows in textures menu
        integer iOldFlags = llList2Integer(g_lElementFlags, iElementIndex);
        iLinkFlags = iLinkFlags & iOldFlags;
        g_lElementFlags = llListReplaceList(g_lElementFlags, [iLinkFlags], iElementIndex, iElementIndex);
        if (iLinkFlags & 16 & ~iOldFlags) {
          g_iNumHideableElements++;
        }
      }
    }
  }
}

UserCommand(integer iNum, string sStr, key kID, integer bRemenu) {
  string sStrLower = llToLower(sStr);
  // This is needed as we react on touch for our "choose element on touch" feature, else we get an element on every collar touch!
  list lParams = llParseString2List(sStrLower, [" "], []);
  integer iFace;
  if (~llListFindList(g_lCommands, [llList2String(lParams, 0)]) || (llList2String(lParams, 0) == "menu" && ~llListFindList(g_lCommands, [llList2String(lParams, 1)]))) { // This is for us....
    if (kID == g_kWearer || iNum == CMD_OWNER) { // Only allowed users can...
      lParams = llParseString2List(sStr, [" "], []);
      string sCommand = llToLower(llList2String(lParams, 0));
      string sElement = llList2String(lParams,1);
      //Debug("Command: "+sCommand+"\nElement: "+sElement);
      if (sCommand == "themes" || sStrLower == "menu themes") {
        sElement = llGetSubString(sStr, 7, -1);
        integer iElementIndex = llListFindList(g_lThemes, [sElement]);
        if (~iElementIndex) {
          g_sThemesNotecardReadType = "processing";
          g_iThemesNotecardLine = 1 + llList2Integer(g_lThemes, iElementIndex + 1);
          g_kSetThemeUser = kID;
          g_iSetThemeAuth = iNum;
          llMessageLinked(LINK_DIALOG, NOTIFY, "1" + "Applying the " + sElement + " theme...", kID);
          llMessageLinked(LINK_ROOT, 601, "themes " + sElement, g_kWearer);
          g_kThemesNotecardRead = llGetNotecardLine(g_sThemesCard, g_iThemesNotecardLine);
        } else if (g_kThemesCardUUID) {
          if (g_bThemesReady) {
            ThemeMenu(kID, iNum);
          } else {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Themes still loading...", kID);
            if (g_bLooks) {
              LooksMenu(kID, iNum);
            } else {
              llMessageLinked(LINK_ROOT, iNum, "menu Settings", kID);
            }
          }
        } else {
          llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "This %DEVICETYPE% has no themes installed. You can type \"%PREFIX% looks\" to fine-tune your %DEVICETYPE% (NOTE: Basic building knowledge required.)", kID);
          if (g_bLooks) {
            LooksMenu(kID, iNum);
          } else {
            llMessageLinked(LINK_ROOT, iNum, "menu Settings", kID);
          }
        }
      } else if (sCommand == "looks") {
        LooksMenu(kID, iNum);
      } else if (sCommand == "menu") {
        ElementMenu(kID, 0, iNum, sElement);
      } else if (sCommand == "hide" || sCommand == "show" || sCommand == "stealth") {
        if (sElement == "") {
          sElement = g_sDeviceType;
        }

        // Get currently shown state
        integer bCurrentlyShown;
        if (sCommand == "show") bCurrentlyShown = TRUE;
        else if (sCommand == "hide") bCurrentlyShown = FALSE;
        else if (sCommand == "stealth") bCurrentlyShown = g_bCollarHidden;

        if (sElement == g_sDeviceType) {
          g_bCollarHidden = !iCurrentlyShown; // Toggle whole collar visibility
        }

        // Do the actual hiding and re/de-glowing of elements
        integer iLinkCount = llGetNumberOfPrims() + 1;
        while (iLinkCount-- > 1) {
          string sLinkType = LinkType(iLinkCount, "nohide");
          if (sLinkType == sElement || sElement == g_sDeviceType) {
            if (!g_bCollarHidden || sElement == g_sDeviceType ) {
              // Don't change things if collar is set hidden, unless we're doing the hiding now
              llSetLinkAlpha(iLinkCount, (float)iCurrentlyShown, ALL_SIDES);
              // Update glow settings for this link
              integer iGlowsIndex = llListFindList(g_lGlows, [iLinkCount]);
              if (iCurrentlyShown) { // Restore glow if it is now shown
                if (~iGlowsIndex) { // If it had a glow, restore it, otherwise don't
                  float fGlow = (float)llList2String(g_lGlows, iGlowsIndex + 1);
                  llSetLinkPrimitiveParamsFast(iLinkCount, [
                    PRIM_GLOW, ALL_SIDES, fGlow
                  ]);
                }
              } else { // Save glow and switch it off if it is now hidden
                float fGlow = llList2Float(llGetLinkPrimitiveParams(iLinkCount, [PRIM_GLOW, 0]), 0);
                if (fGlow > 0) { // If it glows, store glow
                  if (~iGlowsIndex) {
                    g_lGlows = llListReplaceList(g_lGlows, [fGlow], iGlowsIndex + 1, iGlowsIndex + 1);
                  } else {
                    g_lGlows += [iLinkCount, fGlow];
                  }
                } else if (~iGlowsIndex) {
                  g_lGlows = llDeleteSubList(g_lGlows, iGlowsIndex, iGlowsIndex + 1); // Remove glow from list
                }

                llSetLinkPrimitiveParamsFast(iLinkCount, [ // Set no glow;
                  PRIM_GLOW, ALL_SIDES, 0.0
                ]);
              }
            }
          }
        }
      } else if (sCommand == "shiny") {
        string sShiny = llList2String(lParams, 2);
        integer iShinyIndex = llListFindList(g_lShiny, [sShiny]);
        if (~iShinyIndex) {
          sShiny = (string)iShinyIndex; // If found, convert string to index and overwrite supplied string
        }
        integer iShiny = (integer)sShiny; // Cast string to integer, we now have the index, or 0 for a bad value

        if (sShiny == "") {
          ShinyMenu(kID, iNum, sStr);
        } else if (iShiny || sShiny == "0") { // If we have a value, or if 0 was passed in as a string value
          integer iLinkCount = llGetNumberOfPrims() + 1;
          while (iLinkCount-- > 2) {
            string sLinkType = LinkType(iLinkCount, "no" + sCommand);
            if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement == "ALL")) {
              if (iShiny < 4) {
                llSetLinkPrimitiveParamsFast(iLinkCount, [
                  PRIM_SPECULAR, g_iTextureFace, (string)NULL_KEY, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0, <1.0, 1.0, 1.0>, 0, 0,
                  PRIM_BUMP_SHINY, ALL_SIDES, iShiny, 0
                ]);
              } else {
                llSetLinkPrimitiveParamsFast(iLinkCount, [
                  PRIM_SPECULAR, g_iTextureFace, (string)TEXTURE_BLANK, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0, <1.0, 1.0, 1.0>, 80, 2
                ]);
              }
            }
          }

          llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "shininess_" + sElement + "=" + (string)iShiny, "");

          if (bRemenu) {
            ShinyMenu(kID, iNum, "shiny "+sElement);
          }
        }
      }
      else if (sCommand == "glow") {
        string sGlow = llList2String(lParams, 2);
        integer iGlowIndex = llListFindList(g_lGlow, [sGlow]);
        float fGlow = (float)sGlow;
        if (~iGlowIndex) {
          sGlow = (string)llList2String(g_lGlow, iGlowIndex + 1); // If found, convert string to index and overwrite supplied string
          fGlow = llList2Float(g_lGlow, iGlowIndex + 1); // Cast string to float, we now have the index, or 0 for a bad value
        }

        if (sGlow == "") { // Got no value for glow, make glow menu
          GlowMenu(kID, iNum, sStr);
        } else if ((fGlow >= 0.0 && fGlow <= 1.0) || sGlow == "0") { // If we have a value, or if 0 was passed in as a string value
          integer iLinkCount = llGetNumberOfPrims() + 1;
          while (iLinkCount-- > 2) {
            string sLinkType = LinkType(iLinkCount, "no" + sCommand);
            if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement == "ALL")) {
              //Debug("Setting Glow for link " + (string)iLinkCount+" to " + (string)fGlow);
              llSetLinkPrimitiveParamsFast(iLinkCount, [
                PRIM_GLOW, g_iTextureFace, fGlow
              ]);
            }
          }

          llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "glow_" + sElement + "=" + (string)fGlow, "");

          if (bRemenu) {
            GlowMenu(kID, iNum, "glow " + sElement);
          }
        }
      } else if (sCommand == "color") {
        //Debug("Color command:" + sStr);
        string sColor = llDumpList2String(llDeleteSubList(lParams, 0, 1), " ");
        if (sColor != "") {
          integer iLinkCount = llGetNumberOfPrims() + 1;
          vector vColorValue = (vector)sColor;
          while (iLinkCount-- > 2) {
            string sLinkType = LinkType(iLinkCount, "nocolor");
            if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement == "ALL")) {
              llSetLinkColor(iLinkCount, vColorValue, g_iTextureFace); // Set link to new color
            }
          }

          llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "color_" + sElement + "=" + sColor, "");

          if (bRemenu) {
            ColorMenu(kID, 0, iNum, sCommand + " " + sElement);
          }
        } else {
          ColorMenu(kID, 0, iNum, sCommand+" "+sElement);
        }
      } else if (sCommand == "normal") {
        integer iTextureIndex = llListFindList(g_lTextures, [g_sNormalMap]);
        if (iTextureIndex >= 0) {
          g_sNormalMap = llList2String(g_lTextureKeys, iTextureIndex);
        }

        integer iLinkCount = llGetNumberOfPrims() + 1;
        while (iLinkCount-- > 2) {
          string sLinkType = LinkType(iLinkCount, "notexture");
          if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
            if (g_iTextureFace != -1) { // !ALL_FACES
              list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_NORMAL, g_iTextureFace]);
              lPrimParams = llDeleteSubList(lPrimParams, 0, 0); // Get texture params
              llSetLinkPrimitiveParamsFast(iLinkCount, [
                PRIM_NORMAL, g_iTextureFace, g_sNormalMap
              ] + lPrimParams);
            } else {
              integer iSides = llGetLinkNumberOfSides(iLinkCount);
              integer iFace;
              for (; iFace < iSides; iFace++) {
                list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_NORMAL, iFace]);
                lPrimParams = llDeleteSubList(lPrimParams, 0, 0); // Get texture params
                llSetLinkPrimitiveParamsFast(iLinkCount, [
                  PRIM_NORMAL, iFace, g_sNormalMap
                ] + lPrimParams);
              }
            }
          }
        }
      } else if (sCommand == "specular") {
        integer iTextureIndex = llListFindList(g_lTextures, [g_sSpecularMap]);
        if (iTextureIndex >=0) {
          g_sSpecularMap = llList2String(g_lTextureKeys, iTextureIndex);
        }

        integer iLinkCount = llGetNumberOfPrims() + 1;
        while (iLinkCount-- > 2) {
          string sLinkType = LinkType(iLinkCount, "notexture");
          if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
            if (g_iTextureFace != -1 ) { // ! ALL_FACES
              list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_SPECULAR, g_iTextureFace]);
              lPrimParams = llDeleteSubList(lPrimParams, 0, 0); // Get texture params
              llSetLinkPrimitiveParamsFast(iLinkCount, [
                PRIM_SPECULAR, g_iTextureFace, g_sSpecularMap
              ] + lPrimParams);
            } else {
              integer iSides = llGetLinkNumberOfSides(iLinkCount);
              integer iFace;
              for (; iFace < iSides; iFace++) {
                list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_SPECULAR, iFace]);
                lPrimParams = llDeleteSubList(lPrimParams, 0, 0); // Get texture params
                llSetLinkPrimitiveParamsFast(iLinkCount, [
                  PRIM_SPECULAR, iFace, g_sSpecularMap
                ] + lPrimParams);
              }
            }
          }
        }
      } else if (sCommand == "texture") {
        //Debug("Texture command:" + sStr);
        string sTextureShortName = llDumpList2String(llDeleteSubList(lParams, 0, 1), " ");
        if (sTextureShortName == "Default") { // If we have one, set the default texture for this element type, else error and give texture menu
          integer iDefaultTextureIndex = llListFindList(g_lTextureDefaults, [sElement]);
          if (~iDefaultTextureIndex) {
            sTextureShortName = llList2String(g_lTextureDefaults, iDefaultTextureIndex + 1);
          }
        }

        // Get long name from short name
        integer iTextureIndex = llListFindList(g_lTextures, [sElement + "~" + sTextureShortName]); // First try to get index of custom texture
        if ((key)sTextureShortName) {
          iTextureIndex = 0; // We have been given a key, so pretend we found it in the list
        } else if (!~iTextureIndex) {
          iTextureIndex = llListFindList(g_lTextures, [sTextureShortName]); // Else get index of regular texture
        }

        if (sTextureShortName == "") { // No texture name supplied, send texture menu for this element
          TextubRemenu(kID, 0, iNum, sStr);
        } else if (!~iTextureIndex) { // Invalid texture name supplied, send texture menu for this element
          llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Sorry! The \"" + sTextureShortName + "\" texture doesn't fit on this particular element, please try another.", kID);

          if (bRemenu) {
            TextubRemenu(kID, 0, iNum, sCommand + " " + sElement);
          }
        } else { // Valid element and texture names supplied, apply texture
          // Get key from long name
          //Debug("Texture command is good:" + sStr);
          string sTextureKey;
          if ((key)sTextureShortName) {
            sTextureKey = sTextureShortName;
          } else {
            sTextureKey = llList2String(g_lTextureKeys, iTextureIndex);
          }
          //Debug("Key for " + sTextureShortName+" is " + sTextureKey);
          // Loop through prims and apply texture key
          integer iLinkCount = llGetNumberOfPrims() + 1;
          while (iLinkCount-- > 2) {
            string sLinkType = LinkType(iLinkCount, "notexture");
            if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
              //Debug("Applying texture to element number " + (string)iLinkCount);
              // Update prim texture for each face with save texture repeats, offsets and rotations
              if (g_iTextureFace != -1) { // !ALL_FACES
                list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_TEXTURE, g_iTextureFace]);
                lPrimParams = llDeleteSubList(lPrimParams, 0, 0); // Get texture params
                llSetLinkPrimitiveParamsFast(iLinkCount, [
                  PRIM_TEXTURE, g_iTextureFace, sTextureKey
                ] + lPrimParams);
              } else {
                integer iSides = llGetLinkNumberOfSides(iLinkCount);
                integer iFace;
                for (; iFace < iSides; iFace++) {
                  list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_TEXTURE, iFace]);
                  lPrimParams = llDeleteSubList(lPrimParams, 0, 0); // Get texture params
                  llSetLinkPrimitiveParamsFast(iLinkCount, [
                    PRIM_TEXTURE, iFace, sTextureKey
                  ] + lPrimParams);
                }
              }
            //} else {
            //  Debug("Not applying texture to element number " + (string)iLinkCount);
            }
          }

          // Ssave to settings
          llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "texture_" + sElement + "=" + sTextureShortName, "");

          if (bRemenu) {
            TextubRemenu(kID, 0, iNum, sCommand + " " + sElement);
          }
        }
      }
    } else { // Anyone else gets an error
      llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "%NOACCESS%", kID);
      llMessageLinked(LINK_ROOT, iNum, "menu Settings", kID);
    }
  }
}

default {
  state_entry() {
    if (llGetInventoryType(g_sThemesCard) != INVENTORY_NOTECARD && llGetInventoryType(".meshthemes") == INVENTORY_NOTECARD) {
      // Our NC isn't here, but oc_meshthemes' is.  Get out of the way.
      llRemoveInventory(llGetScriptName());
    }

    g_kWearer = llGetOwner();
    BuildTexturesList();
    BuildElementsList();
    BuildThemesList();
    //Debug("Starting");
  }

  link_message(integer iSender, integer iNum, string sStr, key kID) {
    if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
      UserCommand(iNum, sStr, kID, FALSE);
    } else if (iNum == LM_SETTING_RESPONSE) {
      list lParams = llParseString2List(sStr, ["="], []);
      string sID = llList2String(lParams, 0);
      string sValue = llList2String(lParams, 1);
      integer i = llSubStringIndex(sID, "_");
      string sCategory = llGetSubString(sID, 0, i);
      string sToken = llGetSubString(sID, i + 1, -1);

      if (sID == "global_DeviceType") g_sDeviceType = sValue;
      else if (sID == "intern_looks") g_bLooks = (integer)sValue;
      else if (sCategory == "texture_") {
        i = llListFindList(g_lTextureDefaults, [sToken]);
        if (~i) {
          g_lTextureDefaults = llListReplaceList(g_lTextureDefaults, [sValue], i + 1, i + 1);
        } else {
          g_lTextureDefaults += [sToken, sValue];
        }
      } else if (sCategory == "shininess_") {
        i = llListFindList(g_lShinyDefaults, [sToken]);
        if (~i) {
          g_lShinyDefaults = llListReplaceList(g_lShinyDefaults, [sValue], i + 1, i + 1);
        } else {
          g_lShinyDefaults += [sToken, sValue];
        }
      } else if (sCategory == "hide_") {
        i = llListFindList(g_lHideDefaults, [sToken]);
        if (~i) {
          g_lHideDefaults = llListReplaceList(g_lHideDefaults, [sValue], i + 1, i + 1);
        } else {
          g_lHideDefaults += [sToken, sValue];
        }
      } else if (sCategory == "color_") {
        i = llListFindList(g_lColorDefaults, [sToken]);
        if (~i) {
          g_lColorDefaults = llListReplaceList(g_lColorDefaults, [sValue], i + 1, i + 1);
        } else {
          g_lColorDefaults += [sToken, sValue];
        }
      }
    } else if (iNum == DIALOG_RESPONSE) {
      integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
      if (iMenuIndex != -1) {
        list lMenuParams = llParseString2List(sStr, ["|"], []);
        key kAv = (key)llList2String(lMenuParams, 0);
        string sMessage = llList2String(lMenuParams, 1);
        //integer iPage = (integer)llList2String(lMenuParams, 2);
        integer iAuth = (integer)llList2String(lMenuParams, 3);
        string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);

        g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

        if (llSubStringIndex(sMenu, "ElementMenu~") == 0) {
          if (sMessage == "BACK") {
            LooksMenu(kAv, iAuth);
          } else {
            string sMenuType = llList2String(llParseString2List(sMenu, ["~"], []), 1);
            UserCommand(iAuth, sMenuType + " " + sMessage, kAv, TRUE);
            /*
            if (sMessage == "*Touch*") {
              llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Please touch the part of the %DEVICETYPE% you want to change. Press Ctrl+Alt+T to see invisible parts.", kAv);
              key kTouchID = llGenerateKey();
              llMessageLinked(LINK_ROOT, TOUCH_REQUEST, (string)kAv + "|3|" + (string)iAuth, kTouchID); // 3 = touchStart and touchEnd
              integer iIndex = llListFindList(g_lMenuIDs, [kID]);
              if (~iIndex) {
                g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kTouchID, sMenuType], iIndex, iIndex + g_iMenuStride - 1);
              } else {
                g_lMenuIDs += [kID, kTouchID, sMenuType];
              }
            } else {
              UserCommand(iAuth, sMenuType + " " + sMessage, kAv, TRUE);
            }
            */
          }
        } else if (sMenu == "LooksMenu~menu" && sMessage == "BACK") {
          llMessageLinked(LINK_ROOT, iAuth, "menu Settings", kAv);
        } else {
          string sBreadcrumbs = llList2String(llParseString2List(sMenu,["~"], []), 1);
          string sBackMenu = llList2String(llParseString2List(sBreadcrumbs, [" "], []), 0);
          //Debug(sBreadcrumbs + " " + sMessage);
          if (sMessage == "BACK") {
            if (~llSubStringIndex(sMenu, "ThemeMenu~themes")) {
              if (g_bLooks) {
                LooksMenu(kAv, iAuth);
              } else {
                llMessageLinked(LINK_ROOT, iAuth, "menu Settings", kAv);
              }
            } else {
              ElementMenu(kAv, 0, iAuth, sBackMenu);
            }
          } else {
            UserCommand(iAuth, sBreadcrumbs + " " + sMessage, kAv, TRUE);
          }
        }
      }
    } else if (iNum == TOUCH_RESPONSE) {
      integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]); // We hid the touch request in the menu details... naughty!!
      if (iMenuIndex != -1) { // Got a response meant for us. Pull out values
        list lParams = llParseString2List(sStr, ["|"], []);
        key kAv = (key)llList2String(lParams, 0);
        integer iAuth = (integer)llList2String(lParams, 1);
        integer iLinkNumber = (integer)llList2String(lParams, 3);

        // Remove stride from g_lMenuIDs.  We have to subtract from the index because the dialog id comes in the middle of the stride
        string sTouchType = llList2String(g_lMenuIDs, iMenuIndex + 1);
        g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

        string sElement = LinkType(iLinkNumber, "no" + sTouchType);
        if (sElement == "immutable") {
          llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "You can't change the " + sTouchType + " of the part you selected. You can try again.", kAv);
          //Debug("calling usercommand with: " + sTouchType);
          UserCommand(iAuth, sTouchType, kAv, TRUE);
        } else {
          //Debug("calling usercommand with: " + sTouchType + " " + sElement);
          UserCommand(iAuth, sTouchType + " " + sElement, kAv, TRUE);
        }
      }
    } else if (iNum == DIALOG_TIMEOUT) {
      integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
      g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
    } else if (iNum == LINK_UPDATE) {
      if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
      else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
    } else if (iNum == REBOOT && sStr == "reboot") {
      llResetScript();
    }
  }

  dataserver(key kID, string sData) {
    if (kID == g_kTexturesNotecardRead) {
      if (sData != EOF) {
        if (llStringTrim(sData, STRING_TRIM) != "" && llGetSubString(sData, 0, 1) != "//") {
          list lThisLine = llParseString2List(sData, [","], []);
          key kTextureKey = (key)llStringTrim(llList2String(lThisLine, 1), STRING_TRIM);
          string sTextureName = llStringTrim(llList2String(lThisLine, 0), STRING_TRIM);
          string sShortName = llList2String(llParseString2List(sTextureName, ["~"], []), -1);

          if (~llListFindList(g_lTextures, [sTextureName])) {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Texture " + sTextureName + " is in the %DEVICETYPE% AND the notecard.  %DEVICETYPE% texture takes priority.", g_kWearer);
          } else if( (key)kTextureKey) { // If the notecard has valid key, and texture is not already in collar
            if (llStringLength(sShortName) > 23) {
              llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Texture " + sTextureName + " in textures notecard too long, dropping.", g_kWearer);
            } else {
              g_lTextures += sTextureName;
              g_lTextureKeys += kTextureKey;
              g_lTextureShortNames += sShortName;
            }
          } else {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Texture key for " + sTextureName + " in textures notecard not recognised, dropping.", g_kWearer);
          }
        }

        g_kTexturesNotecardRead = llGetNotecardLine(g_sTextureCard, ++g_iTexturesNotecardLine);
      }
    } else if (kID == g_kThemesNotecardRead) {
      if (sData != EOF) {
        sData = llStringTrim(sData, STRING_TRIM);
        if (sData!="" && llSubStringIndex(sData, "#") != 0) {
          if (llGetSubString(sData, 0, 0) == "[") {
            //Debug("(" + g_sThemesNotecardReadType + ")[good line]:" + sData);
            sData = llGetSubString(sData, llSubStringIndex(sData, "[") + 1, llSubStringIndex(sData, "]" ) - 1);
            sData = llStringTrim(sData, STRING_TRIM);

            if (g_sThemesNotecardReadType == "initialize") { // Reading notecard to determine theme names
              g_lThemes += [sData, g_iThemesNotecardLine];
            } else if (sData == g_sThemesNotecardReadType) { // We just found our section
              g_sThemesNotecardReadType = "processing";
              g_sCurrentTheme = sData;
            } else if (g_sThemesNotecardReadType == "processing") { // We just found the start of the next section, we're done
              /*
              if (!g_bLeashParticle) {
                llMessageLinked(LINK_SET, CMD_WEARER, "particle reset", "");
              } else {
                g_bLeashParticle = FALSE;
              }
              */
              //llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Theme \"" + g_sCurrentTheme + "\" applied!", g_kSetThemeUser);
              llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Applied!", g_kSetThemeUser);
              UserCommand(g_iSetThemeAuth, "themes", g_kSetThemeUser, TRUE);
              return;
            }

            g_iTextureFace = -1;
            g_kThemesNotecardRead = llGetNotecardLine(g_sThemesCard, ++g_iThemesNotecardLine);
          } else {
            if (g_sThemesNotecardReadType == "processing"){
              //Debug("[good line]:" + sData);
              //Debug("iLeash=" + (string)g_bLeashParticle);
              // Do what the notecard says
              list lParams = llParseStringKeepNulls(sData, ["~"], []);
              string sElement = llStringTrim(llList2String(lParams, 0), STRING_TRIM);
              if (sElement != "") {
                if (~llSubStringIndex(sElement, "particle")) {
                  //Debug("[good line]:" + sData);
                  //llMessageLinked(LINK_THIS, CMD_WEARER, "particle reset", "");
                  integer i;
                  for (i = 1; i < llGetListLength(lParams); i += 2) {
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "particle_" + llList2String(lParams, i) + "=" + llList2String(lParams, i + 1), "");
                    llMessageLinked(LINK_THIS, LM_SETTING_RESPONSE, "particle_" + llList2String(lParams, i) + "=" +  llList2String(lParams, i + 1), "");
                  }
                  llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "theme particle sent","");
                  g_bLeashParticle = TRUE;
                } else {
                  list lSubcommands = ["texture", "color", "shiny", "glow", "hide", "show", "face", "normal", "specular"];
                  integer bSuccess;
                  integer i;
                  for (i = 1; i < llGetListLength(lParams); i++) {
                    string sSubstring = llStringTrim(llList2String(lParams, i), STRING_TRIM);
                    if (sSubstring != "") {
                      list lSubParams = llParseString2List(sSubstring, ["="], []);
                      string sCmd = llList2String(lSubParams, 0);
                      sData = llList2String(lSubParams, 1);
                      if (~llListFindList(lSubcommands, [sCmd])) {
                        if (sCmd == "face") {
                          lParams = llDeleteSubList(lParams, i, i);
                          g_iTextureFace = (integer)sData;
                          i--;
                        } else if (sCmd == "normal") {
                          lParams = llDeleteSubList(lParams, i, i);
                          g_sNormalMap = sData;
                          i--;
                        } else if (sCmd == "specular") {
                          lParams = llDeleteSubList(lParams, i, i);
                          g_sSpecularMap = sData;
                          i--;
                        } else {
                          bSuccess = TRUE;
                        }

                        UserCommand(g_iSetThemeAuth, sCmd + " " + sElement + " " + sData, g_kSetThemeUser, FALSE);
                      }
                    }
                  }

                  if (!bSuccess) { // Old themes format
                    for (i = 0; i < 4; i++) {
                      sData = llStringTrim(llList2String(lParams, i + 1), STRING_TRIM);
                      if (sData != "" && sData != ",,") {
                        UserCommand(g_iSetThemeAuth, llList2String(lSubcommands, i ) + " " + sElement + " " + sData, g_kSetThemeUser, FALSE);
                      }
                    }
                  }
                }

                g_iTextureFace = -1;
                //g_sNormalMap = "";
                //g_sSpecularMap = "";
              }
            }

            g_kThemesNotecardRead = llGetNotecardLine(g_sThemesCard, ++g_iThemesNotecardLine);
          }
        } else {
          g_kThemesNotecardRead = llGetNotecardLine(g_sThemesCard, ++g_iThemesNotecardLine);
        }
      } else {
        if (g_sThemesNotecardReadType == "processing") { // We just found the end of file, we're done
          /*
          if (!g_bLeashParticle) {
            llMessageLinked(LINK_SET, CMD_WEARER, "particle reset", "");
          } else {
            g_bLeashParticle = FALSE;
          }
          */
          //llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Theme \""+g_sCurrentTheme+"\" applied!", g_kSetThemeUser);
          llMessageLinked(LINK_DIALOG, NOTIFY, "0" + "Applied!", g_kSetThemeUser);
          UserCommand(g_iSetThemeAuth, "themes", g_kSetThemeUser, TRUE);
        } else {
          g_bThemesReady = TRUE;
          //Debug(llDumpList2String(g_lThemes,","));
        }
      }
    }
  }

  changed(integer iChange) {
    if (iChange & CHANGED_LINK) BuildElementsList();
    if (iChange & CHANGED_OWNER) llResetScript();

    if (iChange & CHANGED_INVENTORY) {
      if (llGetInventoryType(g_sTextureCard) == INVENTORY_NOTECARD && llGetInventoryKey(g_sTextureCard) != g_kTextureCardUUID) {
        BuildTexturesList();
      } else if (llGetInventoryType(g_sTextureCard) != INVENTORY_NOTECARD) {
        g_kTextureCardUUID == "";
      }

      if (llGetInventoryType(g_sThemesCard) == INVENTORY_NOTECARD && llGetInventoryKey(g_sThemesCard) != g_kThemesCardUUID) {
        BuildThemesList();
      } else if (llGetInventoryType(g_sThemesCard) != INVENTORY_NOTECARD) {
        g_kThemesCardUUID = "";
      }
    }
  }
}
