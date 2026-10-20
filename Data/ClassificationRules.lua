--===========================================================================
-- EzWoW - Utility Bar
-- Data/ClassificationRules.lua : Item & Spell Classification Rules
--===========================================================================
local _, ns = ...

local lowerText = ns.LowerText

ns.Data = ns.Data or {}

ns.Data.CLASS_REAGENTS = {
    MAGE    = { [17020] = 5, [17031] = 5, [17032] = 5, [17056] = 5 },
    PRIEST  = { [17028] = 5, [17029] = 5, [17056] = 5 },
    PALADIN = { [21177] = 20, [17033] = 2 },
    DRUID   = { [17034] = 2, [17035] = 2, [17036] = 2, [17037] = 2, [17038] = 2, [17021] = 5, [17026] = 5, [22148] = 5 },
    SHAMAN  = { [17030] = 2, [17057] = 5, [17058] = 5 },
    WARLOCK = { [6265] = 3, [5565] = 1, [16583] = 1 },
    ROGUE   = { [5140] = 5, [5530] = 5 },
}

ns.Data.WEAPON_BUFF_ITEMS = {
    -- Rogue Poisons
    [6947] = true, [6949] = true, [6950] = true, [8926] = true, [8927] = true,
    [8928] = true, [22053] = true, [22054] = true, [43230] = true, [43231] = true,
    [2892] = true, [2893] = true, [8984] = true, [8985] = true, [20844] = true,
    [22055] = true, [43232] = true, [43233] = true, [3775] = true, [3776] = true,
    [5237] = true, [6951] = true, [9186] = true, [21835] = true, [43234] = true,
    [43235] = true, [10918] = true, [10920] = true, [10921] = true, [10922] = true,
    [22056] = true, [43236] = true, [43237] = true,
    -- Sharpening Stones, Weightstones & Weapon Oils
    [2862] = true, [2863] = true, [2871] = true, [7964] = true, [12404] = true,
    [18262] = true, [23122] = true, [23528] = true, [23529] = true, [41191] = true,
    [3239] = true, [3240] = true, [3241] = true, [7965] = true, [12643] = true,
    [28420] = true, [28421] = true, [3824] = true, [3829] = true, [20744] = true,
    [20745] = true, [20746] = true, [20747] = true, [20748] = true, [20749] = true,
    [20750] = true, [22521] = true, [22522] = true, [23123] = true,
    -- Fishing Lures
    [6529] = true, [6530] = true, [6532] = true, [6533] = true,
    [6811] = true, [7307] = true, [34861] = true, [46006] = true,
}

ns.Data.CAMPING_ITEMS = {
    [279938] = true, [279940] = true, [279941] = true, [279943] = true, [279944] = true,
    [279945] = true, [279947] = true, [279948] = true, [279949] = true, [279950] = true,
    [279951] = true, [279952] = true, [279955] = true, [279956] = true, [279957] = true,
    [279959] = true, [279960] = true, [279961] = true, [279962] = true, [279964] = true,
    [279965] = true, [279966] = true, [279967] = true, [279968] = true, [279969] = true,
    [279970] = true, [279972] = true, [279973] = true, [279974] = true, [279976] = true,
    [279978] = true, [279979] = true, [279981] = true, [279982] = true, [279985] = true,
    [279987] = true, [279988] = true, [279989] = true, [279990] = true,
}

ns.Data.FORM_PATTERNS = {
    DRUID   = { "곰 변신", "광포한 곰 변신", "표범 변신", "날쌘 동물 변신", "여행 변신", "수중 동물 변신", "치타 변신", "달빛야수 변신", "나무정령 변신", "bear form", "dire bear form", "cat form", "travel form", "aquatic form", "moonkin form", "tree of life", "flight form" },
    WARRIOR = { "전투 태세", "방어 태세", "광폭 태세", "battle stance", "defensive stance", "berserker stance" },
    ROGUE   = { "은신", "stealth" },
    HUNTER  = { "치타의 상", "매의 상", "원숭이의 상", "야수의 상", "독사의 상", "치타 무리의 상", "야생의 상", "용매의 상", "aspect of" },
    PALADIN = { "기원의 오라", "응보의 오라", "집중의 오라", "성전사의 오라", "저항의 오라", "헌신의 오라", "devotion aura", "retribution aura", "concentration aura", "crusader aura", "resistance aura", "shadow resistance aura", "frost resistance aura", "fire resistance aura", "sanctity aura" },
    SHAMAN  = { "늑대 정령", "ghost wolf" },
    PRIEST  = { "어둠의 형상", "shadowform" },
    WARLOCK = { "악마의 형상", "metamorphosis" },
}

ns.Data.CAMPING_SPELLS = {
    "basic campfire", "작은 모닥불", "기본 모닥불", "수습 모닥불", "숙련 모닥불",
    "journeyman campfire", "expert campfire",
}

ns.Data.PROFESSION_KEYWORDS = {
    "disenchant", "enchanting", "engineering", "leatherworking", "alchemy", "blacksmithing",
    "tailoring", "skinning", "smelting", "fishing", "cooking", "first aid", "mining",
    "jewelcrafting", "prospecting", "inscription", "milling", "survival",
    "find herbs", "find minerals", "find treasure",
    "마력 추출", "마법부여", "기계공학", "가죽세공", "연금술", "대장기술", "재봉술",
    "무두질", "제련", "낚시", "요리", "응급치료", "채광", "보석세공", "보석 추출",
    "주문각인", "제분", "생존기술", "광물 찾기", "약초 찾기", "보물 찾기",
}

ns.Data.TRAVEL_SPELLS = {
    "군마 소환", "천리마 소환", "지옥마 소환", "공포마 소환", "해골마 소환",
    "영혼의 귀환", "달숲으로 순간이동", "달숲 순간이동", "귀환", "천상의 귀환",
    "순간이동:", "순간이동 ", "차원문:", "차원문 ", "포탈 열기", "포탈열기",
    "소환 의식", "전력 질주", "질주", "점멸", "저속 낙하", "공중 부양",
    "수면 걷기", "수중 호흡", "영원의 숨결", "철수",
    "summon warhorse", "summon charger", "summon felsteed", "summon dreadsteed",
    "astral recall", "teleport: moonglade", "teleport:", "portal:", "teleport ", "portal ",
    "ritual of summoning", "sprint", "dash", "blink", "slow fall", "levitate",
    "water walking", "water breathing", "unending breath", "disengage",
    "召唤战马", "召喚戰馬", "召唤地狱战马", "召喚地獄戰馬", "召唤恐惧战马", "召喚恐懼戰馬",
    "星界传送", "星界傳送", "传送", "傳送", "传送门", "傳送門", "召唤仪式", "召喚儀式",
    "疾跑", "闪现术", "閃現術", "缓落术", "緩落術", "漂浮术", "漂浮術", "水上行走", "水下呼吸",
    "призыв коня", "призыв скакуна", "астральное возвращение", "телепортация", "портал:",
    "ритуал призыва", "спринт", "порыв", "скачок", "замедленное падение", "левитация",
    "хождение по воде", "подводное дыхание",
}

local UTILITY_PREFIXES = {
    "부활", "환생", "되살리기", "야수 되살리기", "구원", "선조의 영혼", "부활의 기원", "천상의 중재",
    "resurrection", "resurrect", "redemption", "rebirth", "revive pet", "ancestral spirit", "reincarnation", "resurrection prayer", "divine intervention",
    "은신", "숨기", "천리안", "독수리의 눈", "정신의 시야", "야수의 눈", "킬로그의 눈", "주의 분산", "소매치기",
    "stealth", "prowl", "far sight", "eagle eye", "mind vision", "eyes of the beast", "eye of kilrogg", "distract", "pick pocket",
    "추적", "야수 추적", "인간형 추적", "언데드 추적", "악마 추적", "용족 추적", "정령 추적", "거인 추적", "은신 추적",
    "야수 부르기", "야수 소환", "야수 해제", "야수 먹이주기", "야수 치료", "야수 되살리기",
    "track ", "tracking ", "detect ", "call pet", "dismiss pet", "feed pet", "mend pet",
    "음식 창조", "물 창조", "생명석 창조", "영혼석 창조", "화염석 창조", "주문석 창조",
    "마법 증폭", "마법 감쇠", "저주 해제", "독 해제", "질병 치료", "독 치료", "정화", "마법 무효화",
    "야생의 징표", "가시", "인내의 기원", "축복", "자유의 축복", "보호의 축복",
    "자물쇠 따기", "독 제조", "무기 독 바르기",
    "conjure food", "conjure water", "create healthstone", "create soulstone", "create firestone", "create spellstone",
    "amplify magic", "dampen magic", "remove curse", "abolish poison", "cure poison", "cure disease",
    "abolish disease", "purify", "cleanse", "dispel magic", "mark of the wild", "thorns", "prayer of fortitude",
    "blessing of ", "pick lock", "apply poison",
    "复活", "复生", "救赎", "救贖", "先祖之魂",
    "潜行", "潛行", "追踪", "追蹤", "召唤", "召喚", "祝福", "隐形", "隱形",
    "воскрешение", "возрождение", "оживление",
    "незаметность", "выслеживание", "призыв", "благословение",
}

local UTILITY_EXACT = {
    ["환생"] = true, ["되살리기"] = true, ["부활"] = true,
    ["윤회"] = true, ["구원"] = true, ["야수 되살리기"] = true,
    ["revive pet"] = true, ["reincarnation"] = true,
}

local UTILITY_CONTAINS = { "의 축복", "blessing of", "祝福" }

-----------------------------------------------------------------------------
-- Classification Functions
-----------------------------------------------------------------------------
function ns.IsAmmoItem(itemType, itemSubType)
    local t = lowerText(itemType)
    local u = lowerText(itemSubType)
    return t == "projectile" or t == "탄환" or t == "화살" or t == "투사체"
        or t == "боеприпасы" or t == "geschoss" or t == "proyectil" or t == "弹药" or t == "彈藥"
        or u:find("arrow", 1, true) ~= nil or u:find("bullet", 1, true) ~= nil
        or u:find("화살", 1, true) ~= nil or u:find("탄환", 1, true) ~= nil
end

function ns.IsFormSpell(name, playerClass)
    local low = lowerText(name)
    for _, pattern in ipairs(ns.Data.FORM_PATTERNS[playerClass] or {}) do
        if low == pattern or (pattern == "aspect of" and low:find(pattern, 1, true) == 1) then
            return true
        end
    end
    if playerClass == "DRUID" then
        for _, pattern in ipairs(ns.Data.FORM_PATTERNS.DRUID) do
            if low:find(pattern .. " (", 1, true) == 1 then
                return true
            end
        end
    end
    return false
end

function ns.IsClassUtilitySpell(name)
    local low = lowerText(name)
    if UTILITY_EXACT[low] then return true end
    for _, word in ipairs(UTILITY_PREFIXES) do
        if low == word or low:sub(1, #word) == word then
            return true
        end
    end
    for _, word in ipairs(UTILITY_CONTAINS) do
        if low:find(word, 1, true) then
            return true
        end
    end
    return false
end

function ns.DetectEffectKind(tooltipText)
    local t = lowerText(tooltipText)
    if t:find("well fed", 1, true) or t:find("포만감", 1, true)
        or t:find("进食充分", 1, true) or t:find("進食充分", 1, true) or t:find("сытость", 1, true) then
        return "buff"
    end
    local hp = t:find("health", 1, true) or t:find("생명력", 1, true) or t:find("生命", 1, true)
        or t:find("здоровь", 1, true) or t:find("gesundheit", 1, true) or t:find("salud", 1, true)
    local mp = t:find("mana", 1, true) or t:find("마나", 1, true) or t:find("法力", 1, true) or t:find("мана", 1, true)
    if hp and mp then return "both"
    elseif hp then return "health"
    elseif mp then return "mana" end
    return nil
end

function ns.ClassifyItem(name, itemType, itemSubType, tooltipText)
    local s = lowerText(name)
    local t = lowerText(itemType)
    local u = lowerText(itemSubType)
    local tip = lowerText(tooltipText)

    -- 1. Quest Items
    if t:find("quest", 1, true) or t:find("quête", 1, true) or t:find("퀘스트", 1, true)
        or t:find("задани", 1, true) or t:find("misión", 1, true) or t:find("任务", 1, true) or t:find("任務", 1, true)
        or tip:find("퀘스트 아이템", 1, true) or tip:find("quest item", 1, true) then
        return "quest"
    end

    -- 2. Explosives / Bombs (filtered out by category toggle)
    if s:find("폭탄", 1, true) or s:find("다이너마이트", 1, true) or s:find("수류탄", 1, true)
        or s:find("유탄", 1, true) or s:find("지뢰", 1, true) or s:find("폭발물", 1, true)
        or s:find("grenade", 1, true) or s:find("bomb", 1, true) or s:find("bombe", 1, true)
        or s:find("dynamite", 1, true) or s:find("sapper charge", 1, true) or s:find("land mine", 1, true)
        or u:find("explosive", 1, true) or u:find("explosif", 1, true) or u:find("폭발물", 1, true) then
        return "bomb"
    end

    -- 3. Camping Stations & Campfires
    if s:find("야영", 1, true) or s:find("모닥불", 1, true) or s:find("캠프파이어", 1, true) or s:find("캠핑", 1, true)
        or s:find("camping", 1, true) or s:find("campfire", 1, true) or s:find("feu de camp", 1, true)
        or s:find("camp fire", 1, true) or s:find("campsite", 1, true) or s:find("camp tent", 1, true) or s:find("camp chair", 1, true)
        or s:find("露营", 1, true) or s:find("露營", 1, true) or s:find("篝火", 1, true) or s:find("lagerfeuer", 1, true)
        or s:find("палатка", 1, true) or s:find("костёр", 1, true) or s:find("костер", 1, true)
        or tip:find("모닥불", 1, true) or tip:find("야영", 1, true) or tip:find("캠핑", 1, true)
        or tip:find("campfire", 1, true) or tip:find("campsite", 1, true) or tip:find("feu de camp", 1, true)
        or tip:find("lagerfeuer", 1, true) or tip:find("hoguera", 1, true) or tip:find("костёр", 1, true) or tip:find("костра", 1, true)
        or tip:find("篝火", 1, true) or tip:find("露营", 1, true) or tip:find("露營", 1, true) then
        return "camping"
    end

    -- 4. Travel & Mount Items
    if s:find("귀환석", 1, true) or s:find("귀환 두루마리", 1, true) or s:find("hearthstone", 1, true) or s:find("scroll of recall", 1, true)
        or s:find("pierre de foyer", 1, true) or s:find("炉石", 1, true) or s:find("爐石", 1, true)
        or s:find("камень возвращения", 1, true) or s:find("ruhestein", 1, true) or s:find("piedra de hogar", 1, true)
        or s:find("초공간 절단기", 1, true) or s:find("차원 분할기", 1, true) or s:find("웜홀", 1, true)
        or s:find("ultrasafe transporter", 1, true) or s:find("dimensional ripper", 1, true) or s:find("wormhole", 1, true)
        or s:find("고삐", 1, true) or s:find("호루라기", 1, true) or s:find("reins", 1, true) or s:find("rênes", 1, true)
        or s:find("whistle", 1, true) or s:find("sifflet", 1, true) or s:find("bridle", 1, true) or s:find("horn of the", 1, true)
        or s:find("기계타조", 1, true) or s:find("mechanostrider", 1, true) or s:find("해골마", 1, true) or s:find("skeletal horse", 1, true)
        or u == "mount" or u == "monture" or u == "탈것" or u == "坐骑" or u == "坐騎"
        or u == "верховые животные" or u == "reittier" or u == "montura"
        or tip:find("rideable", 1, true) or tip:find("탈 수 있는", 1, true)
        or (tip:find("이동 속도가", 1, true) and tip:find("탈것", 1, true)) then
        return "travel"
    end

    -- 5. Bandages
    if s:find("붕대", 1, true) or s:find("bandage", 1, true) or s:find("verband", 1, true)
        or s:find("venda", 1, true) or s:find("бинт", 1, true) or s:find("绷带", 1, true) or s:find("繃帶", 1, true) then
        return "bandage"
    end

    -- 6. Weapon Buffs (Poisons, Stones, Oils, Lures)
    if s:find("맹독", 1, true) or s:find("마비독", 1, true) or s:find("감염독", 1, true) or s:find("효과독", 1, true)
        or s:find("치명적인 독", 1, true) or s:find("신경 독", 1, true) or s:find("정신 마비 독", 1, true)
        or s:find("상처 감염 독", 1, true) or s:find("순간 효과 독", 1, true) or s:find("발화 독", 1, true) or s:find("마취 독", 1, true)
        or s:find("instant poison", 1, true) or s:find("deadly poison", 1, true) or s:find("crippling poison", 1, true)
        or s:find("mind-numbing poison", 1, true) or s:find("wound poison", 1, true) or s:find("anesthetic poison", 1, true)
        or s:find("숫돌", 1, true) or s:find("무게추", 1, true) or s:find("마술사 오일", 1, true) or s:find("반짝이는 오일", 1, true)
        or s:find("마나 오일", 1, true) or s:find("냉기 오일", 1, true) or s:find("암흑 오일", 1, true)
        or s:find("sharpening stone", 1, true) or s:find("weightstone", 1, true) or s:find("wizard oil", 1, true)
        or s:find("mana oil", 1, true) or s:find("frost oil", 1, true) or s:find("shadow oil", 1, true)
        or s:find("wetzstein", 1, true) or s:find("gewichtsstein", 1, true) or s:find("zauberöl", 1, true) or s:find("manaöl", 1, true)
        or s:find("pierre à aiguiser", 1, true) or s:find("caillou", 1, true) or s:find("huile de sorcier", 1, true) or s:find("huile de mana", 1, true)
        or s:find("piedra de afilar", 1, true) or s:find("piedra de peso", 1, true) or s:find("aceite de zahorí", 1, true) or s:find("aceite de maná", 1, true)
        or s:find("точило", 1, true) or s:find("грузило", 1, true) or s:find("волшебное масло", 1, true) or s:find("масло маны", 1, true)
        or s:find("磨刀石", 1, true) or s:find("平衡石", 1, true) or s:find("巫师之油", 1, true) or s:find("巫師之油", 1, true) or s:find("法力之油", 1, true)
        or s:find("미끼", 1, true) or s:find("물고기 유인기", 1, true) or s:find("bauble", 1, true)
        or s:find("nightcrawlers", 1, true) or s:find("fish attractor", 1, true)
        or tip:find("낚싯대에 사용", 1, true) or tip:find("applied to your fishing pole", 1, true) then
        return "weaponbuff"
    end

    -- 7. Elixirs, Flasks & Scrolls
    if s:find("비약", 1, true) or s:find("영약", 1, true) or s:find("두루마리", 1, true)
        or s:find("elixir", 1, true) or s:find("élixir", 1, true) or s:find("elixier", 1, true)
        or s:find("эликсир", 1, true) or s:find("药剂", 1, true) or s:find("藥劑", 1, true)
        or s:find("flask", 1, true) or s:find("flacon", 1, true) or s:find("fläschchen", 1, true)
        or s:find("frasco", 1, true) or s:find("настой", 1, true) or s:find("合剂", 1, true) or s:find("精煉", 1, true)
        or s:find("scroll of", 1, true) or s:find("parchemin", 1, true) or s:find("rolle der", 1, true)
        or s:find("pergamino", 1, true) or s:find("свиток", 1, true) or s:find("卷轴", 1, true) or s:find("卷軸", 1, true)
        or u:find("elixir", 1, true) or u:find("flask", 1, true) or u:find("scroll", 1, true)
        or u:find("비약", 1, true) or u:find("영약", 1, true) or u:find("두루마리", 1, true) then
        return "elixir"
    end

    -- 8. Potions & Stones
    if s:find("물약", 1, true) or s:find("potion", 1, true) or s:find("trank", 1, true)
        or s:find("poción", 1, true) or s:find("зелье", 1, true) or s:find("药水", 1, true) or s:find("藥水", 1, true)
        or s:find("생명석", 1, true) or s:find("영혼석", 1, true) or s:find("주문석", 1, true) or s:find("화염석", 1, true)
        or s:find("healthstone", 1, true) or s:find("soulstone", 1, true) or s:find("spellstone", 1, true) or s:find("firestone", 1, true)
        or s:find("마나 마노", 1, true) or s:find("마나 비취", 1, true) or s:find("마나 황수정", 1, true)
        or s:find("마나 루비", 1, true) or s:find("마나 에메랄드", 1, true) or s:find("마나석", 1, true)
        or s:find("mana agate", 1, true) or s:find("mana jade", 1, true) or s:find("mana citrine", 1, true)
        or s:find("mana ruby", 1, true) or s:find("mana emerald", 1, true)
        or s:find("엉겅퀴 차", 1, true) or s:find("thistle tea", 1, true)
        or s:find("악마의 룬", 1, true) or s:find("암흑 룬", 1, true) or s:find("demonic rune", 1, true) or s:find("dark rune", 1, true)
        or s:find("채찍뿌리 줄기", 1, true) or s:find("어둠용의 숨결", 1, true)
        or s:find("whipper root tuber", 1, true) or s:find("night dragon's breath", 1, true)
        or u:find("potion", 1, true) or u:find("물약", 1, true) then
        return "potion"
    end

    -- 9. Food & Drink
    if u:find("food", 1, true) or u:find("drink", 1, true) or u:find("nourriture", 1, true)
        or u:find("음식", 1, true) or u:find("음료", 1, true)
        or s:find("빵", 1, true) or s:find("음료", 1, true) or s:find("구이", 1, true)
        or s:find("스튜", 1, true) or s:find("수프", 1, true) or s:find("스테이크", 1, true)
        or tip:find("음식을 먹으려면", 1, true) or tip:find("음료를 마시려면", 1, true)
        or tip:find("must remain seated while", 1, true) then
        return "food"
    end

    -- 10. Engineering Gadgets
    if tip:find("engineering", 1, true) or tip:find("ingénierie", 1, true) or tip:find("기계공학", 1, true)
        or tip:find("工程学", 1, true) or tip:find("工程學", 1, true) or tip:find("инженерн", 1, true)
        or tip:find("ingenieurskunst", 1, true) or tip:find("ingenier", 1, true)
        or u == "devices" or u == "appareils" or u == "장치" then
        return "engineering"
    end

    return "other"
end

local BEST_FILTER_CATEGORIES = { food = true, potion = true, bandage = true }

local function IsBestFilterCandidate(entry)
    return entry.type == "item"
        and not entry.inventorySlot
        and BEST_FILTER_CATEGORIES[entry.category]
        and (entry.effect or entry.category == "bandage")
end

function ns.FilterBestConsumables(entries)
    local playerLevel = (type(UnitLevel) == "function" and UnitLevel("player")) or 999
    local function computeScore(d)
        if d.minLevel > playerLevel then return -1 end
        return d.minLevel * 10000 + d.ilvl * 10 + math.min(d.count or 1, 9)
    end

    local bestIndexByKey = {}
    for idx, entry in ipairs(entries) do
        if IsBestFilterCandidate(entry) then
            local key = entry.category .. ":" .. (entry.effect or "")
            local prevIdx = bestIndexByKey[key]
            if not prevIdx or computeScore(entry) > computeScore(entries[prevIdx]) then
                bestIndexByKey[key] = idx
            end
        end
    end

    local filtered = {}
    for idx, entry in ipairs(entries) do
        local key = entry.category .. ":" .. (entry.effect or "")
        if not IsBestFilterCandidate(entry) or bestIndexByKey[key] == idx then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end
