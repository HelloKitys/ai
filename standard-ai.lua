sgs.ai_skill_invoke.jianxiong = function(self, data)
	return true
end

table.insert(sgs.ai_global_flags, "hujiasource")

sgs.ai_skill_invoke.hujia = function(self, data)
	local cards = self.player:getHandcards()
	if sgs.hujiasource then return false end	
	for _, friend in ipairs(self.friends_noself) do
		if friend:getKingdom() == "wei" and self:isEquip("EightDiagram", friend) then return true end		
	end

	local wei_num = 0
	local others = self.room:getOtherPlayers(self.player)
	for _, other in sgs.qlist(others) do
		if other:getKingdom() == "wei" and other:isAlive() then wei_num = wei_num + 1 end
	end
	
	local current = self.room:getCurrent()
	if self:isFriend(current) and current:getKingdom() == "wei" and self:getOverflow(current) >2 then
		return true
	end

	for _, card in sgs.qlist(cards) do
		if card:isKindOf("Jink") then
			return false
		end
	end
	return wei_num>0 and others:length()>1
end

sgs.ai_choicemade_filter.skillInvoke.hujia = function(player, promptlist)
	if promptlist[#promptlist] == "yes" then
		sgs.hujiasource = player
	end
end

function sgs.ai_slash_prohibit.hujia(self, to, card, from)
	if self:isFriend(to) then return false end
	local guojia = self.room:findPlayerBySkillName("tiandu")
	if guojia and guojia:getKingdom() == "wei" and self:isFriend(to, guojia) then return sgs.ai_slash_prohibit.tiandu(self, guojia) end
end

sgs.ai_choicemade_filter.cardResponded["@hujia-jink"] = function(player, promptlist)
	if promptlist[#promptlist] ~= "_nil_" then
		sgs.updateIntention(player, sgs.hujiasource, -80)
		sgs.hujiasource = nil
	elseif sgs.hujiasource then
		local lieges = player:getRoom():getLieges("wei", sgs.hujiasource)
		if lieges and not lieges:isEmpty() then
			if player:objectName() == lieges:last():objectName() then
				sgs.hujiasource = nil
			end
		end
	end
end

sgs.ai_skill_cardask["@hujia-jink"] = function(self)
	if not self.room:getLord() then return "." end
	local yuanshu = self.room:findPlayerBySkillName("weidi")
	if not sgs.hujiasource and not yuanshu then sgs.hujiasource = self.room:getLord() end
	if not sgs.hujiasource then return "." end
	if not self:isFriend(sgs.hujiasource) then return "." end
	if self:needBear() then return "." end
	local bgm_zhangfei = self.room:findPlayerBySkillName("dahe")
	if bgm_zhangfei and bgm_zhangfei:isAlive() and sgs.hujiasource:hasFlag("dahe") then
		for _, card in ipairs(self:getCards("Jink")) do
			if card:getSuit() == sgs.Card_Heart then
				return card:getId()
			end
		end
		return "."
	end
	return self:getCardId("Jink") or "."
end

sgs.ai_skill_invoke.fankui = function(self, data)
	local target = data:toPlayer()
	if sgs.ai_need_damaged.fankui(self, target, self.player) then return true end

	if self:isFriend(target) then
		if self:getOverflow(target) > 2 then return true end
		if self:doNotDiscard(target) then return true end
		return (self:hasSkills(sgs.lose_equip_skill, target) and not target:getEquips():isEmpty()) 
		  or (self:needToThrowArmor(target) and target:getArmor()) or self:doNotDiscard(target)
	end
	if self:isEnemy(target) then
		if self:doNotDiscard(target) then return false end
		return true
	end
	--self:updateLoyalty(-0.8*sgs.ai_loyalty[target:objectName()],self.player:objectName())
	return true
end

sgs.ai_choicemade_filter.cardChosen.fankui = function(player, promptlist, self)
	if sgs.fankui_target then
		local intention = 10
		local id = promptlist[3]
		local card = sgs.Sanguosha:getCard(id)
		local target = sgs.fankui_target
		if self:needToThrowArmor(target) and self.room:getCardPlace(id) == sgs.Player_PlaceEquip and card:isKindOf("Armor") then
			intention = -intention
		elseif self:doNotDiscard(target) then intention = -intention
		elseif self:hasSkills(sgs.lose_equip_skill, target) and not target:getEquips():isEmpty() and
			self.room:getCardPlace(id) == sgs.Player_PlaceEquip and card:isKindOf("EquipCard") then
				intention = -intention
		elseif sgs.ai_need_damaged.fankui(self, target, player) then intention = 0
		elseif self:getOverflow(target) > 2 then intention = 0
		end
		sgs.updateIntention(player, target, intention)
		sgs.fankui_target = nil
	end
end

sgs.ai_skill_cardchosen.fankui = function(self, who, flags)
	local suit = sgs.ai_need_damaged.fankui(self, who, self.player)
	if not suit then return nil end

	local cards = sgs.QList2Table(who:getEquips())
	local handcards = sgs.QList2Table(who:getHandcards())
	if #handcards==1 and handcards[1]:hasFlag("visible") then table.insert(cards,handcards[1]) end

	for i=1,#cards,1 do
		if (cards[i]:getSuit() == suit and suit ~= sgs.Card_Spade) or
			(cards[i]:getSuit() == suit and suit == sgs.Card_Spade and cards[i]:getNumber() >= 2 and cards[i]:getNumber()<=9) then
			return cards[i]
		end
	end
	return nil
end


sgs.ai_need_damaged.fankui = function (self, attacker, player)
	if not player:hasSkill("guicai") or not player:hasSkill("fankui") then return false end
	local need_retrial = function(target)
		local alive_num = self.room:alivePlayerCount()
		return alive_num + target:getSeat() % alive_num > self.room:getCurrent():getSeat() 
				and target:getSeat() < alive_num + player:getSeat() % alive_num				
	end
	local retrial_card ={["spade"]=nil,["heart"]=nil,["club"]=nil}
	local attacker_card ={["spade"]=nil,["heart"]=nil,["club"]=nil}
	
	local handcards = sgs.QList2Table(player:getHandcards())
	for i=1,#handcards,1 do
		if handcards[i]:getSuit() == sgs.Card_Spade and handcards[i]:getNumber()>=2 and handcards[i]:getNumber()<=9 then
			retrial_card.spade = true
		end
		if handcards[i]:getSuit() == sgs.Card_Heart then
			retrial_card.heart = true
		end
		if handcards[i]:getSuit() == sgs.Card_Club then
			retrial_card.club = true
		end
	end

	local cards = sgs.QList2Table(attacker:getEquips())
	local handcards = sgs.QList2Table(attacker:getHandcards())
	if #handcards==1 and handcards[1]:hasFlag("visible") then table.insert(cards,handcards[1]) end

	for i=1,#cards,1 do
		if cards[i]:getSuit() == sgs.Card_Spade and cards[i]:getNumber()>=2 and cards[i]:getNumber()<=9 then
			attacker_card.spade = sgs.Card_Spade
		end
		if cards[i]:getSuit() == sgs.Card_Heart then
			attacker_card.heart = sgs.Card_Heart
		end
		if cards[i]:getSuit() == sgs.Card_Club then
			attacker_card.club = sgs.Card_Club
		end
	end

	local players = self.room:getOtherPlayers(player)
	for _, aplayer in sgs.qlist(players) do
		if aplayer:containsTrick("lightning") and self:getFinalRetrial(aplayer) ==1 and need_retrial(aplayer) then
			if not retrial_card.spade and attacker_card.spade then return attacker_card.spade end
		end

		if self:isFriend(aplayer, player) and not aplayer:containsTrick("YanxiaoCard") and not aplayer:hasSkill("qiaobian") then

			if aplayer:containsTrick("indulgence") and self:getFinalRetrial(aplayer) ==1 and need_retrial(aplayer) and aplayer:getHandcardNum()>=aplayer:getHp() then
				if not retrial_card.heart and attacker_card.heart then return attacker_card.heart end
			end

			if aplayer:containsTrick("supply_shortage") and self:getFinalRetrial(aplayer) ==1 and need_retrial(aplayer) and self:hasSkills("yongshi",aplayer) then
				if not retrial_card.club and attacker_card.club then return attacker_card.club end
			end
		end
	end
	return false
end


sgs.ai_skill_cardask["@guicai-card"]=function(self, data)
	local judge = data:toJudge()

	if self:needRetrial(judge) then
		local cards = sgs.QList2Table(self.player:getHandcards())
		local card_id = self:getRetrialCardId(cards, judge)
		local card = sgs.Sanguosha:getCard(card_id)
		if card_id ~= -1 then
			return "@GuicaiCard[" .. card:getSuitString() .. ":" .. card:getNumberString() .. "]=" .. card_id
		end
	end

	return "."
end

function sgs.ai_cardneed.guicai(to, card, self)
	for _, player in sgs.qlist(self.room:getAllPlayers()) do
		if self:getFinalRetrial(to) == 1 then 
			if player:containsTrick("lightning") and not player:containsTrick("YanxiaoCard") then
				return card:getSuit() == sgs.Card_Spade and card:getNumber() >= 2 and card:getNumber() <= 9 and not self:hasSkills("hongyan|wuyan")
			end
			if self:isFriend(player) and self:willSkipDrawPhase(player) then
				return card:getSuit() == sgs.Card_Club
			end
			if self:isFriend(player) and self:willSkipPlayPhase(player) then
				return card:getSuit() == sgs.Card_Heart
			end
		end
	end
end

sgs.guicai_suit_value = {
	heart = 3.9,
	club = 3.9,
	spade = 3.5
}

sgs.ai_chaofeng.simayi = -2

sgs.ai_skill_invoke.ganglie = function(self, data)
	local mode = self.room:getMode()
	if mode:find("_mini_41") then return true end
	local who = data:toPlayer()
	if self:isFriend(who) and (self:getDamagedEffects(who, self.player) or self:needToLoseHp(who, self.player, nil, true)) then
		return true
	end
	if self:getDamagedEffects(who, self.player) and self:isEnemy(who) then 
		return false
	end
	
	return not self:isFriend(who)
end

sgs.ai_choicemade_filter.skillInvoke.ganglie = function(player, promptlist, self)
	if sgs.ganglie_target then
		local target = sgs.ganglie_target
		local intention = 10
		if promptlist[3] == "yes" then
			if self:getDamagedEffects(target, player) or self:needToLoseHp(target, player, nil, true) then
				intention = 0
			end
			sgs.updateIntention(player, target, intention)
		elseif self:canAttack(target) then
			sgs.updateIntention(player, target, -10)
		end
	end
	sgs.ganglie_target = nil
end

sgs.ai_need_damaged.ganglie = function (self, attacker, player)
	if not player:hasSkill("ganglie") then return false end
	if self:isEnemy(attacker, player) and attacker:getHp() + attacker:getHandcardNum() <= 3
		and not self:hasSkills("buqu", attacker)
		and not (self:needKongcheng(attacker) and attacker:getHandcardNum() > 1)
		and sgs.isGoodTarget(attacker, self.enemies, self) 
		and not self:getDamagedEffects(attacker, player) and not self:needToLoseHp(attacker, player) then
			return true
	end
	return false
end

sgs.ai_skill_discard.ganglie = function(self, discard_num, min_num, optional, include_equip)
	local xiahou = self.room:findPlayerBySkillName("ganglie")
	if self:getDamagedEffects(self.player, xiahou) or self:needToLoseHp(self.player, xiahou) then return {} end
	local to_discard = {}
	local cards = sgs.QList2Table(self.player:getHandcards())
	local index = 0
	local all_peaches = 0
	for _, card in ipairs(cards) do
		if card:isKindOf("Peach") then
			all_peaches = all_peaches + 1
		end
	end
	if all_peaches >= 2 and self:getOverflow() <= 0 then return {} end
	self:sortByKeepValue(cards)
	cards = sgs.reverse(cards)

	for i = #cards, 1, -1 do
		local card = cards[i]
		if not card:isKindOf("Peach") and not self.player:isJilei(card) then
			table.insert(to_discard, card:getEffectiveId())
			table.remove(cards, i)
			index = index + 1
			if index == 2 then break end
		end
	end	
	if #to_discard < 2 then return {} 
	else
		return to_discard
	end
end

function sgs.ai_slash_prohibit.ganglie(self, to, card, from)
	if from:hasSkill("jueqing") then return false end
	if from:hasSkill("nosqianxi") and from:distanceTo(to) == 1 then return false end
	if from:hasFlag("nosjiefanUsed") then return false end
	return from:getHandcardNum() + from:getHp() < 4
end

sgs.ai_chaofeng.xiahoudun = -3

sgs.ai_skill_use["@@tuxi"] = function(self, prompt)
	self:sort(self.enemies, "handcard_defense")
	local targets = {}

	local zhugeliang = self.room:findPlayerBySkillName("kongcheng")
	local luxun = self.room:findPlayerBySkillName("lianying")
	local dengai = self.room:findPlayerBySkillName("tuntian")
	local jiangwei = self.room:findPlayerBySkillName("zhiji")
	
	local add_player = function (player,isfriend)
		if player:getHandcardNum() ==0 or player:objectName() == self.player:objectName() then return #targets end
		if self:objectiveLevel(player) == 0 and player:isLord() and sgs.current_mode_players["rebel"] > 1 then return #targets end
		if #targets == 0 then 
			table.insert(targets, player:objectName())
		elseif #targets== 1 then			
			if player:objectName()~=targets[1] then 
				table.insert(targets, player:objectName()) 
			end
		end
		if isfriend and isfriend == 1 then
			self.player:setFlags("tuxi_isfriend_"..player:objectName())
		end
		return #targets
	end
	
	local lord = self.room:getLord()
	if lord and self:isEnemy(lord) and sgs.turncount == 1 and not lord:isKongcheng() then
		add_player(self.room:getLord())
	end

	if jiangwei and self:isFriend(jiangwei) and jiangwei:getMark("zhiji") == 0 and jiangwei:getHandcardNum()== 1 
			and self:getEnemyNumBySeat(self.player,jiangwei) <= (jiangwei:getHp() >= 3 and 1 or 0) then
		if add_player(jiangwei,1) == 2  then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end
	end

	if dengai and self:isFriend(dengai) and (not self:isWeak(dengai) or self:getEnemyNumBySeat(self.player,dengai) == 0 ) 
			and dengai:hasSkill("zaoxian") and dengai:getMark("zaoxian") == 0 and dengai:getPile("field"):length() == 2 and add_player(dengai, 1) == 2 then 
		return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) 
	end

	if zhugeliang and self:isFriend(zhugeliang) and zhugeliang:getHandcardNum() == 1 and self:getEnemyNumBySeat(self.player,zhugeliang) > 0 then
		if zhugeliang:getHp() <= 2 then
			if add_player(zhugeliang,1) == 2 then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end
		else
			local flag = string.format("%s_%s_%s","visible",self.player:objectName(),zhugeliang:objectName())					
			local cards = sgs.QList2Table(zhugeliang:getHandcards())
			if #cards == 1 and (cards[1]:hasFlag("visible") or cards[1]:hasFlag(flag)) then
				if cards[1]:isKindOf("TrickCard") or cards[1]:isKindOf("Slash") or cards[1]:isKindOf("EquipCard") then
					if add_player(zhugeliang,1) == 2 then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end
				end				
			end
		end
	end

	if luxun and self:isFriend(luxun) and luxun:getHandcardNum() == 1 and self:getEnemyNumBySeat(self.player,luxun) > 0 then	
		local flag = string.format("%s_%s_%s","visible",self.player:objectName(),luxun:objectName())
		local cards = sgs.QList2Table(luxun:getHandcards())
		if #cards==1 and (cards[1]:hasFlag("visible") or cards[1]:hasFlag(flag)) then
			if cards[1]:isKindOf("TrickCard") or cards[1]:isKindOf("Slash") or cards[1]:isKindOf("EquipCard") then
				if add_player(luxun,1)==2  then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end
			end
		end	
	end
	
	for i = 1, #self.enemies, 1 do
		local p = self.enemies[i]
		local cards = sgs.QList2Table(p:getHandcards())
		local flag = string.format("%s_%s_%s","visible",self.player:objectName(),p:objectName())
		for _, card in ipairs(cards) do
			if (card:hasFlag("visible") or card:hasFlag(flag)) and (card:isKindOf("Peach") or card:isKindOf("Nullification") or card:isKindOf("Analeptic") ) then
				if add_player(p)==2  then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end
			end
		end
	end

	for i = 1, #self.enemies, 1 do
		local p = self.enemies[i]
		if self:hasSkills("jijiu|qingnang|xinzhan|leiji|jieyin|beige|kanpo|liuli|qiaobian|zhiheng|guidao|longhun|xuanfeng|tianxiang|lijian", p) then
			if add_player(p) == 2  then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end
		end
	end
	
	for i = 1, #self.enemies, 1 do
		local p = self.enemies[i]
		local x = p:getHandcardNum()
		local good_target = true				
		if x == 1 and self:needKongcheng(p) then good_target = false end
		if x >= 2 and p:hasSkill("tuntian") and p:hasSkill("zaoxian") then good_target = false end
		if good_target and add_player(p)==2 then return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) end				
	end


	if luxun and add_player(luxun,(self:isFriend(luxun) and 1 or nil)) == 2 then 
		return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) 
	end

	if dengai and self:isFriend(dengai) and dengai:hasSkill("zaoxian") and (not self:isWeak(dengai) or self:getEnemyNumBySeat(self.player,dengai) == 0 ) and add_player(dengai,1) == 2 then 
		return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2]) 
	end
	
	local others = self.room:getOtherPlayers(self.player)
	for _, other in sgs.qlist(others) do
		if self:objectiveLevel(other) >= 0 and not (other:hasSkill("tuntian") and other:hasSkill("zaoxian")) and add_player(other) == 2 then
			return ("@TuxiCard=.->%s+%s"):format(targets[1], targets[2])
		end
	end

	for _, other in sgs.qlist(others) do
		if self:objectiveLevel(other) >= 0 and not (other:hasSkill("tuntian") and other:hasSkill("zaoxian")) and add_player(other) == 1 and math.random(0, 5) <= 1 and not self:hasSkills("qiaobian") then
			return ("@TuxiCard=.->%s"):format(targets[1])
		end
	end

	return "."
end

sgs.ai_card_intention.TuxiCard = function(self,card, from, tos, source)
	local lord = getLord(self.player)
	local tuxi_lord = false
	if sgs.evaluateRoleTrends(from) == "neutral" and sgs.evaluateRoleTrends(tos[1]) == "neutral" and
		(not tos[2] or sgs.evaluateRoleTrends(tos[2]) == "neutral") and lord and not lord:isKongcheng() and 
		not (self:needKongcheng(lord) and lord:getHandcardNum() == 1 ) and
		self:hasLoseHandcardEffective(lord) and not (lord:hasSkill("tuntian") and lord:hasSkill("zaoxian")) and from:aliveCount() >= 4 then
			sgs.updateIntention(from, lord, -80)
		return
	end
	if from:getState() == "online" then
		for _, to in ipairs(tos) do
			if to:hasSkill("kongcheng") or to:hasSkill("lianying") or to:hasSkill("zhiji") 
				or (to:hasSkill("tuntian") and to:hasSkill("zaoxian")) then
				sgs.updateIntention(from, to, 0)
			else
				sgs.updateIntention(from, to, 80)
			end
		end
	else
		for _, to in ipairs(tos) do
			if lord and to:objectName() == lord:objectName() then tuxi_lord = true end
			local intention = from:hasFlag("tuxi_isfriend_"..to:objectName()) and -5 or 80
			sgs.updateIntention(from, to, intention)
		end
		if sgs.turncount ==1 and not tuxi_lord and lord and not lord:isKongcheng() and from:getRoom():alivePlayerCount() > 2 then 
			sgs.updateIntention(from, lord, -80) 
		end
	end
end

sgs.ai_chaofeng.zhangliao = 4

sgs.ai_skill_invoke.luoyi = function(self,data)
	if self.player:isSkipped(sgs.Player_Play) then return false end
	if self:needBear() then return false end
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	local slashtarget = 0
	local dueltarget = 0
	self:sort(self.enemies,"hp")
	for _,card in ipairs(cards) do
		if card:isKindOf("Slash") then
			for _,enemy in ipairs(self.enemies) do
				if self.player:canSlash(enemy, card, true) and self:slashIsEffective(card, enemy) and self:objectiveLevel(enemy) > 3 and sgs.isGoodTarget(enemy, self.enemies, self) then
					if getCardsNum("Jink", enemy) < 1 or (self:isEquip("Axe") and self.player:getCards("he"):length() > 4) then
						slashtarget = slashtarget + 1
					end
				end
			end
		end
		if card:isKindOf("Duel") then
			for _, enemy in ipairs(self.enemies) do
				if self:getCardsNum("Slash") >= getCardsNum("Slash", enemy) and sgs.isGoodTarget(enemy, self.enemies, self)
				and self:objectiveLevel(enemy) > 3 and not self:cantbeHurt(enemy, 2)
				and self:damageIsEffective(enemy) and enemy:getMark("@late") < 1 then
					dueltarget = dueltarget + 1 
				end
			end
		end
	end		
	if (slashtarget+dueltarget) > 0 then
		self:speak("luoyi")
		return true
	end
	return false
end

function sgs.ai_cardneed.luoyi(to, card, self)
	local slash_num = 0
	local target
	local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	
	local cards = to:getHandcards()
	local need_slash = true
	for _, c in sgs.qlist(cards) do
		local flag = string.format("%s_%s_%s","visible",self.room:getCurrent():objectName(),to:objectName())
		if c:hasFlag("visible") or c:hasFlag(flag) then
			if isCard("Slash", c, to) then
				need_slash = false
				break
			end	  
		end
	end
	
	self:sort(self.enemies, "defenseSlash")
	for _, enemy in ipairs(self.enemies) do
		if to:canSlash(enemy) and not self:slashProhibit(slash ,enemy) and self:slashIsEffective(slash, enemy) and sgs.getDefenseSlash(enemy) <= 2 then
			target = enemy
			break
		end
	end
	
	if need_slash and target and isCard("Slash", card, to) then return true end
	return isCard("Duel",card, to)  
end

sgs.luoyi_keep_value = {
	Peach 			= 6,
	Analeptic 		= 5.8,
	Jink 			= 5.2,
	Duel			= 5.5,
	FireSlash 		= 5.6,
	Slash 			= 5.4,
	ThunderSlash 	= 5.5,	
	Axe				= 5,
	Blade 			= 4.9,
	Spear 			= 4.9,
	Fan				= 4.8,
	KylinBow		= 4.7,
	Halberd			= 4.6,
	MoonSpear		= 4.5,
	SPMoonSpear = 4.5,
	DefensiveHorse 	= 4
}

sgs.ai_chaofeng.xuchu = 3

sgs.ai_skill_invoke.tiandu = sgs.ai_skill_invoke.jianxiong

function sgs.ai_slash_prohibit.tiandu(self, to, card, from)
	if self:canLiegong(to, from) then return false end
	if self:isEnemy(to) and self:isEquip("EightDiagram", to) and not IgnoreArmor(from, to) and #self.enemies > 1 then return true end
end

function SmartAI:IsLihunTarget(player, DrawCardNum)
	player = player or self.player
	DrawCardNum = DrawCardNum or 1
	
	if type(player) == "table" then
		if #player == 0 then return false end
		local found
		for _, ap in ipairs(player) do
			if self:IsLihunTarget(ap, DrawCardNum) then found = true break end			
		end
		if found then return true
		else return false
		end
	end
	
	local HandCardNum = player:getHandcardNum() + DrawCardNum
	local sb_diaochan = self.room:findPlayerBySkillName("lihun")
	if not sb_diaochan then return false end
	if not player:isMale() or self:isFriend(player, sb_diaochan) or sb_diaochan:hasUsed("LihunCard") then return false end
	
	if sb_diaochan:getPhase() == sgs.Player_Play then
		if HandCardNum - player:getHp() >= 2 and sb_diaochan:faceUp() or 
			HandCardNum > 0 and HandCardNum - player:getHp() >= -1 and not sb_diaochan:faceUp() then
			return true
		end
	else
		if sb_diaochan:faceUp() and not self:willSkipPlayPhase(sb_diaochan) and 
		self:playerGetRound(player) > self:playerGetRound(sb_diaochan) and HandCardNum >= player:getHp() + 2 then
			return true
		end
	end
	
	return false
end

sgs.ai_skill_invoke.yiji = function(self)
	local Shenfen_user
	for _, player in sgs.qlist(self.room:getAlivePlayers()) do
		if player:hasFlag("ShenfenUsing") then
			Shenfen_user = player
			break
		end
	end
	if self.player:getHandcardNum() < 2 then return true end
	local invoke
	for _, friend in ipairs(self.friends) do
		if not (friend:hasSkill("manjuan") and friend:getPhase() == sgs.Player_NotActive) and 
			not self:needKongcheng(friend, true) and not self:IsLihunTarget(friend) and 
			(not Shenfen_user or Shenfen_user:objectName() == friend:objectName() or friend:getHandcardNum() >= 4) then
				invoke = true
			break
		end
	end
	return invoke
end

sgs.ai_skill_askforyiji.yiji = function(self, card_ids)

	local cards = {}
	for _, card_id in ipairs(card_ids) do
		table.insert(cards, sgs.Sanguosha:getCard(card_id))
	end
	
	local Shenfen_user
	for _, player in sgs.qlist(self.room:getAlivePlayers()) do
		if player:hasFlag("ShenfenUsing") then
			Shenfen_user = player
			break
		end
	end
	
	if Shenfen_user then
		if self:isFriend(Shenfen_user) then
			if Shenfen_user:objectName() ~= self.player:objectName() then
				for _, id in ipairs(card_ids) do
					return Shenfen_user, id
				end
			else
				return nil, -1
			end
		else
			if self.player:getHandcardNum() < self:getOverflow(false, true) then
				return nil, -1
			end
			local card, friend = self:getCardNeedPlayer(cards)
			if card and friend and friend:getHandcardNum() >=4 then
				return friend, card:getId()
			end
		end
	end
	
	if self.player:getHandcardNum() <= 2 and not Shenfen_user then
		return nil, -1
	end
			
	local new_friends = {}
	local CanKeep
	for _, friend in ipairs(self.friends) do
		if not (friend:hasSkill("manjuan") and friend:getPhase() == sgs.Player_NotActive) and 
		not self:needKongcheng(friend, true) and not self:IsLihunTarget(friend) and 
		(not Shenfen_user or friend:objectName() == Shenfen_user:objectName() or friend:getHandcardNum() >= 4) then
			if friend:objectName() == self.player:objectName() then CanKeep = true
			else 
				table.insert(new_friends, friend)
			end
		end
	end

	if #new_friends > 0 then
		local card, target = self:getCardNeedPlayer(cards)
		if card and target then
			for _, friend in ipairs(new_friends) do
				if target:objectName() == friend:objectName() then
					return friend, card:getEffectiveId()
				end
			end
		end
		if Shenfen_user and self:isFriend(Shenfen_user) then
			return Shenfen_user, cards[1]:getEffectiveId()
		end
		self:sort(new_friends, "defense")
		self:sortByKeepValue(cards, true)
		return new_friends[1], cards[1]:getEffectiveId()
	elseif CanKeep then
		return nil, -1
	else
		local other = {}
		for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if not (self:IsLihunTarget(player) and self:isFriend(player)) and (self:isFriend(player) or not player:hasSkill("lihun")) then
				table.insert(other, player)
			end
		end
		return other[math.random(1, #other)], card_ids[math.random(1, #card_ids)]
	end

end

sgs.ai_need_damaged.yiji = function (self, attacker, player)
	if not player:hasSkill("yiji") then return end
	local need_card = false
	local current = self.room:getCurrent()
	if self:isEquip("Crossbow", current) or current:hasSkill("paoxiao") or current:hasFlag("shuangxiong") then need_card = true end
	if self:hasSkills("jieyin|jijiu",current) and self:getOverflow(current) <= 0 then need_card = true end
	if self:isFriend(current, player) and need_card then return true end
	
	local friends = {}
	for _, ap in sgs.qlist(self.room:getAlivePlayers()) do
		if self:isFriend(ap, player) then
			table.insert(friends, ap)
		end
	end
	self:sort(friends, "hp")

	if friends[1]:objectName() == player:objectName() and self:isWeak(player) and self:getCardsNum("Peach", player) == 0 then return false end
	if #friends > 1 and self:isWeak(friends[2]) then return true end	
	
	return player:getHp() > 2 and sgs.turncount > 2 and #friends > 1
end

sgs.ai_chaofeng.guojia = -4

sgs.ai_view_as.qingguo = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card:isBlack() and card_place ~= sgs.Player_PlaceEquip then
		return ("jink:qingguo[%s:%s]=%d"):format(suit, number, card_id)
	end
end

function sgs.ai_cardneed.qingguo(to, card)
	return to:getCards("h"):length() < 2 and card:isBlack()
end

function SmartAI:willSkipPlayPhase(player, NotContains_Null)
	local player = player or self.player
	local friend_null = 0
	local friend_snatch_dismantlement = 0
	local cp = self.room:getCurrent()
	if self.player:objectName() == cp:objectName() and self.player:objectName() ~= player:objectName() and self:isFriend(player) then
		for _, hcard in sgs.qlist(self.player:getCards("he")) do
			if (isCard("Snatch", hcard, self.player) and self.player:distanceTo(player) == 1) or isCard("Dismantlement", hcard, self.player) then
				local trick = sgs.Sanguosha:cloneCard(hcard:objectName(), hcard:getSuit(), hcard:getNumber())
				if self:hasTrickEffective(trick, player) then friend_snatch_dismantlement = friend_snatch_dismantlement + 1 end
			end
		end
	end
	if not NotContains_Null then
		for _, p in sgs.qlist(self.room:getAllPlayers()) do
			if self:isFriend(p, player) then friend_null = friend_null + getCardsNum("Nullification", p) end
			if self:isEnemy(p, player) then friend_null = friend_null - getCardsNum("Nullification", p) end
		end
	end
	if player:containsTrick("indulgence") then
		if player:containsTrick("YanxiaoCard") or self:hasSkills("keji|conghui",player) or (self:hasSkills("qiaobian",player) and not player:isKongcheng()) then return false end
		if friend_null + friend_snatch_dismantlement > 1 then return false end
		return true
	end
	return false
end

function SmartAI:willSkipDrawPhase(player, NotContains_Null)
	local player = player or self.player
	local friend_null = 0
	local friend_snatch_dismantlement = 0
	local cp = self.room:getCurrent()
	if not NotContains_Null then
		for _, p in sgs.qlist(self.room:getAllPlayers()) do
			if self:isFriend(p, player) then friend_null = friend_null + getCardsNum("Nullification", p) end
			if self:isEnemy(p, player) then friend_null = friend_null - getCardsNum("Nullification", p) end
		end
	end
	if self.player:objectName() == cp:objectName() and self.player:objectName() ~= player:objectName() and self:isFriend(player) then
		for _, hcard in sgs.qlist(self.player:getCards("he")) do
			if (isCard("Snatch", hcard, self.player) and self.player:distanceTo(player) == 1) or isCard("Dismantlement", hcard, self.player) then
				local trick = sgs.Sanguosha:cloneCard(hcard:objectName(), hcard:getSuit(), hcard:getNumber())
				if self:hasTrickEffective(trick, player) then friend_snatch_dismantlement = friend_snatch_dismantlement + 1 end
			end
		end
	end
	if player:containsTrick("supply_shortage") then
		if player:containsTrick("YanxiaoCard") or self:hasSkills("shensu|jisu",player) or (self:hasSkills("qiaobian",player) and not player:isKongcheng()) then return false end
		if friend_null + friend_snatch_dismantlement > 1 then return false end
		return true
	end
	return false
end

sgs.ai_skill_invoke.luoshen = function(self, data)
 	if self:willSkipPlayPhase() then
		local erzhang = self.room:findPlayerBySkillName("guzheng")
		if erzhang and self:isEnemy(erzhang) then return false end
	end
	return true
end

sgs.qingguo_suit_value = {
	spade = 4.1,
	club = 4.2
}

local rende_skill={}
rende_skill.name="rende"
table.insert(sgs.ai_skills, rende_skill)
rende_skill.getTurnUseCard=function(self)
	if self.player:isKongcheng() then return end
	local mode = string.lower(global_room:getMode())
	if self.player:usedTimes("RendeCard") > 1 and mode:find("04_1v3") then return end
	if (self:isEquip("Crossbow") or self:getCardsNum("Crossbow") > 0) and self:getCardsNum("Slash") > 0 then
		self:sort(self.enemies, "defense")
		for _, enemy in ipairs(self.enemies) do
			if self.player:distanceTo(enemy) == 1 and (enemy:getHp() == 1 and getCardsNum("Peach", enemy) == 0 or
					not self:hasSkill("fenyong|zhichi|fankui|neoganglie|ganglie|enyuan|nosenyuan|langgu|guixin", enemy)) then
				local slashs = self:getCards("Slash")
				local slash_count = 0
				for _, slash in ipairs(slashs) do
					if not self:slashProhibit(slash, enemy) then
						slash_count = slash_count + 1
					end
				end
				if slash_count >= enemy:getHp() then return false end
			end
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if enemy:canSlash(self.player) and not self:slashProhibit(nil, self.player, enemy) and self:playerGetRound(enemy) <= 3 then
			if self:isEquip("GudingBlade", enemy) and self.player:getHandcardNum() == 1 and getCardsNum("Slash", enemy) >= 1 then
				return false
			elseif self:isEquip("Crossbow", enemy) and not (self:getOverflow() > 0) then
				return false
			end
		end
	end
	for _, player in ipairs(self.friends_noself) do
		if (player:hasSkill("haoshi") and not player:containsTrick("supply_shortage")) or player:hasSkill("jijiu") then
			return sgs.Card_Parse("@RendeCard=.")
		end
	end
	if (self.player:usedTimes("RendeCard") < 2 or self:getOverflow() > 0) then
		return sgs.Card_Parse("@RendeCard=.")
	end
	if self.player:getLostHp() < 2 then
		return sgs.Card_Parse("@RendeCard=.")
	end
end

sgs.ai_skill_use_func.RendeCard = function(card, use, self)
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByUseValue(cards,true)
	local name = self.player:objectName()
	local card, friend = self:getCardNeedPlayer(cards)
	if card and friend then
		if friend:objectName()==self.player:objectName() or not self.player:getHandcards():contains(card) then return end
		if friend:hasSkill("enyuan") and #cards>=2 then
			self:sortByUseValue(cards,true)
			for i = 1, #cards, 1 do
				if cards[i]:getId()~=card:getId() then
					use.card = sgs.Card_Parse("@RendeCard=" .. card:getId() .. "+" .. cards[i]:getId())
					break
				end
			end
		else
			use.card = sgs.Card_Parse("@RendeCard=" .. card:getId())
		end
		if use.to then use.to:append(friend) end
		return
	else
		local pangtong = self.room:findPlayerBySkillName("manjuan")
		if not pangtong then return end
		if self.player:isWounded() and self.player:getHandcardNum() >= 3 and self.player:usedTimes("RendeCard") < 2 then
			self:sortByUseValue(cards, true)
			local to_give = {}
			for _, card in ipairs(cards) do
				if not card:isKindOf("Peach") and not card:isKindOf("ExNihilo") then table.insert(to_give, card:getId()) end
				if #to_give == 2 - self.player:usedTimes("RendeCard") then break end
			end
			if #to_give > 0 then
				use.card = sgs.Card_Parse("@RendeCard=" .. table.concat(to_give, "+"))
				if use.to then use.to:append(pangtong) end
				return
			end
		end
	end
end

sgs.ai_use_value.RendeCard = 8.5
sgs.ai_use_priority.RendeCard = 8.8

sgs.ai_card_intention.RendeCard = function(self,card, from, tos)
	local to = tos[1]
	local intention = -70
	if to:hasSkill("manjuan") and to:getPhase() == sgs.Player_NotActive then
		intention = 0
	elseif to:hasSkill("kongcheng") and to:isKongcheng() then
		intention = 30
	end
	sgs.updateIntention(from, to, intention)
end

sgs.dynamic_value.benefit.RendeCard = true

table.insert(sgs.ai_global_flags, "jijiangsource")
local jijiang_filter = function(player, carduse)
	if carduse.card:isKindOf("JijiangCard") then
		sgs.jijiangsource = player
	else
		sgs.jijiangsource = nil
	end
end

table.insert(sgs.ai_choicemade_filter.cardUsed, jijiang_filter)

sgs.ai_skill_invoke.jijiang = function(self, data)
	if sgs.jijiangsource then return false end

	local current = self.room:getCurrent()
	if self:isFriend(current) and current:getKingdom() == "shu" and self:getOverflow(current) > 2 and not self:isEquip("Crossbow", current) then
		return true
	end

	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if card:isKindOf("Slash") then
			return false
		end
	end

	local shu_num = 0
	local others = self.room:getOtherPlayers(self.player)
	for _, other in sgs.qlist(others) do
		if other:getKingdom() == "shu" and other:isAlive() then shu_num = shu_num + 1 end
	end

	return shu_num>0 and others:length()>1
end

sgs.ai_choicemade_filter.skillInvoke.jijiang = function(player, promptlist)
	if promptlist[#promptlist] == "yes" then
		sgs.jijiangsource = player
	end
end

local jijiang_skill = {}
jijiang_skill.name = "jijiang"
table.insert(sgs.ai_skills, jijiang_skill)
jijiang_skill.getTurnUseCard = function(self)
	local lieges = self.room:getLieges("shu", self.player)
	if lieges:isEmpty() then return end
	if self.player:hasUsed("JijiangCard") or not self:slashIsAvailable() then return end
	local card_str = "@JijiangCard=."
	local slash = sgs.Card_Parse(card_str)
	assert(slash)

	return slash
end

sgs.ai_skill_use_func.JijiangCard = function(card,use,self)
	if self.player:hasFlag("jijiang_failed") then return end
	self:sort(self.enemies, "defenseSlash")
	local target_count = 0
	for _, enemy in ipairs(self.enemies) do
		if (self.player:canSlash(enemy, nil, not no_distance) or
			(use.isDummy and self.player:distanceTo(enemy) <= (self.predictedRange or self.player:getAttackRange())))
			and self:objectiveLevel(enemy) > 3 and self:slashIsEffective(card, enemy) and sgs.isGoodTarget(enemy,self.enemies, self) then
			use.card = card
			if use.to then
				use.to:append(enemy)
			end
			target_count = target_count + 1			
			if target_count == 1 then 
				local flag = string.format("jijiang_%s_%s", self.player:objectName(), enemy:objectName())
				self.room:setPlayerFlag(self.player, flag)
			end
			if self.slash_targets <= target_count then return end
		end
	end	
end

sgs.ai_event_callback[sgs.TargetConfirmed].jijiang = function(self, player, data)
	local use = data:toCardUse()
	local to = sgs.QList2Table(use.to)

	if not use.card:isKindOf("JijiangCard") then return end

	self:sort(to, "defense")
	local flag = string.format("jijiang_%s_%s", use.from:objectName(), to[1]:objectName())
	self.room:setPlayerFlag(use.from, flag)
	sgs.jijiangsource = use.from
end



sgs.ai_card_intention.JijiangCard = function(self,card, from, tos)
	if not from:isLord() and global_room:getCurrent():objectName() == from:objectName() then
		return sgs.ai_card_intention.Slash(self, card, from, tos)
	end
end

sgs.ai_use_value.JijiangCard = 8.5
sgs.ai_use_priority.JijiangCard = 2.45

sgs.ai_choicemade_filter.cardResponded["@jijiang-slash"] = function(player, promptlist)
	local clearJijiangTargetFlag = function(jijiangsource)
		if not jijiangsource then return end
		for _, p in sgs.qlist(player:getRoom():getOtherPlayers(jijiangsource)) do
			local flag = string.format("jijiang_%s_%s", jijiangsource:objectName(), p:objectName())
			if jijiangsource:hasFlag(flag) then player:getRoom():setPlayerFlag(jijiangsource, "-"..flag) end
		end
	end
	if promptlist[#promptlist] ~= "_nil_" then
		sgs.updateIntention(player, sgs.jijiangsource, -40)
		clearJijiangTargetFlag(sgs.jijiangsource)
		sgs.jijiangsource = nil
	else
		local lieges = player:getRoom():getLieges("shu", sgs.jijiangsource)
		if lieges and not lieges:isEmpty() then
			if sgs.jijiangsource and player:objectName() == lieges:last():objectName() then
				clearJijiangTargetFlag(sgs.jijiangsource)
				sgs.jijiangsource = nil
			elseif sgs.jijiangsource and player:objectName() == lieges:last():objectName() then	
				sgs.jijiangsource = nil
				sgs.jijiangtarget = nil
			end
		end
	end
end

sgs.ai_skill_cardask["@jijiang-slash"] = function(self, data)
	if not sgs.jijiangsource then return "." end
	if not self:isFriend(sgs.jijiangsource) then return "." end
	if self:needBear() then return "." end
	if self.player:hasFlag("JijiangTarget") and self.player:getRole() == "renegade" and sgs.isGoodTarget(self.player, nil, self) then return "." end
	local target
	for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		local flag = string.format("jijiang_%s_%s", sgs.jijiangsource:objectName(), p:objectName())
		if sgs.jijiangsource:hasFlag(flag) then
			target = p
			break
		end
	end

	if not target then return self:getCardId("Slash") or "." end	
	
	local ignoreArmor = IgnoreArmor(sgs.jijiangsource, target) or not target:getArmor()
	
	if self:isFriend(target) and not (self:needToLoseHp(target, sgs.jijiangsource, true, true) or self:getDamagedEffects(target, sgs.jijiangsource, true)) then return "." end

	if ignoreArmor and not target:hasSkill("yizhong") then return self:getCardId("Slash") or "." end

	local slashes = self:getCards("Slash")
	for _, slash in ipairs(slashes) do
		if not self:slashProhibit(slash, target, sgs.jijiangsource) and self:slashIsEffective(slash, target, nil, sgs.jijiangsource) then
			return slash:toString()
		end
	end	
	
	return "."
end

sgs.ai_chaofeng.liubei = -2

sgs.ai_view_as.wusheng = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card:isRed() and not card:isKindOf("Peach") and not card:hasFlag("using") then
		return ("slash:wusheng[%s:%s]=%d"):format(suit, number, card_id)
	end
end

local wusheng_skill={}
wusheng_skill.name="wusheng"
table.insert(sgs.ai_skills,wusheng_skill)
wusheng_skill.getTurnUseCard=function(self,inclusive)
	local cards = self.player:getCards("he")
	cards=sgs.QList2Table(cards)
	
	local red_card
	
	self:sortByUseValue(cards,true)

	local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	local slashAvail = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_Residue, self.player, slash)
	
	for _,card in ipairs(cards) do
		if card:isRed() and not card:isKindOf("Slash") and not card:isKindOf("Peach") 				--not peach
			and ((self:getUseValue(card)<sgs.ai_use_value.Slash) or inclusive or slashAvail > 1) then
			red_card = card
			break
		end
	end

	if red_card then		
		local suit = red_card:getSuitString()
		local number = red_card:getNumberString()
		local card_id = red_card:getEffectiveId()
		local card_str = ("slash:wusheng[%s:%s]=%d"):format(suit, number, card_id)
		local slash = sgs.Card_Parse(card_str)
		
		assert(slash)
		
		return slash
	end
end

function sgs.ai_cardneed.wusheng(to, card)
	return to:getHandcardNum() < 3 and card:isRed()
end

function sgs.ai_cardneed.paoxiao(to, card, self)
	local cards = to:getHandcards()
	local has_weapon = to:getWeapon() and not to:getWeapon():isKindOf("Crossbow")
	local slash_num = 0
	for _, c in sgs.qlist(cards) do
		local flag=string.format("%s_%s_%s","visible",self.room:getCurrent():objectName(),to:objectName())
		if c:hasFlag("visible") or c:hasFlag(flag) then
			if c:isKindOf("Weapon") and not c:isKindOf("Crossbow") then
				has_weapon=true
			end
			if c:isKindOf("Slash") then slash_num = slash_num +1 end
		end
	end

	if not has_weapon then
		return card:isKindOf("Weapon") and not card:isKindOf("Crossbow")
	else
		return self:isEquip("Spear", to) or card:isKindOf("Slash") or (slash_num>1 and card:isKindOf("Analeptic"))
	end
end

sgs.paoxiao_keep_value = {
	Peach = 6,
	Analeptic = 5.8,
	Jink = 5.7,
	FireSlash = 5.6,
	Slash = 5.4,
	ThunderSlash = 5.5,
	ExNihilo = 4.7
}

sgs.ai_chaofeng.zhangfei = 3

dofile "lua/ai/guanxing-ai.lua"

local longdan_skill={}
longdan_skill.name="longdan"
table.insert(sgs.ai_skills,longdan_skill)
longdan_skill.getTurnUseCard=function(self)
	local cards = self.player:getCards("h")	
	cards=sgs.QList2Table(cards)
	
	local jink_card
	
	self:sortByUseValue(cards,true)
	
	for _,card in ipairs(cards)  do
		if card:isKindOf("Jink") then
			jink_card = card
			break
		end
	end
	
	if not jink_card then return nil end
	local suit = jink_card:getSuitString()
	local number = jink_card:getNumberString()
	local card_id = jink_card:getEffectiveId()
	local card_str = ("slash:longdan[%s:%s]=%d"):format(suit, number, card_id)
	local slash = sgs.Card_Parse(card_str)
	assert(slash)
	
	return slash
		
end

sgs.ai_view_as.longdan = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place ~= sgs.Player_PlaceEquip then
		if card:isKindOf("Jink") then
			return ("slash:longdan[%s:%s]=%d"):format(suit, number, card_id)
		elseif card:isKindOf("Slash") then
			return ("jink:longdan[%s:%s]=%d"):format(suit, number, card_id)
		end
	end
end

sgs.ai_use_priority.longdan = 9

sgs.longdan_keep_value = {
	Peach = 6,
	Analeptic = 5.8,
	Jink = 5.7,
	FireSlash = 5.7,
	Slash = 5.6,
	ThunderSlash = 5.5,
	ExNihilo = 4.7
}

sgs.ai_skill_invoke.tieji = function(self, data)
	local target = data:toPlayer()
	if self:isFriend(target) then return false end

	local zj = self.room:findPlayerBySkillName("guidao")
	if zj and self:isEnemy(zj) and self:canRetrial(zj) then return false end
	
	if target:hasArmorEffect("EightDiagram") and not IgnoreArmor(self.player, target) then return true end
	if target:hasLordSkill("hujia") then
		for _, p in ipairs(self.enemies) do
			if p:getKingdom() == "wei" and (p:hasArmorEffect("EightDiagram") or p:getHandcardNum() > 0) then return true end		
		end
	end	
	if target:hasSkill("longhun") and target:getHp() == 1 and self:hasSuit("club", true, target) then return true end

	if target:isKongcheng() or (self:getKnownNum(target) == target:getHandcardNum() and getKnownCard(target, "Jink", true) == 0) then return false end
	return true
end


sgs.ai_chaofeng.machao = 1

function sgs.ai_cardneed.jizhi(to, card)
	return card:isNDTrick()
end

sgs.jizhi_keep_value = {
	Peach 		= 6,
	Analeptic 	= 5.9,
	Jink 		= 5.8,
	ExNihilo	= 5.7,
	Snatch 		= 5.7,
	Dismantlement = 5.6,
	IronChain 	= 5.5,
	SavageAssault=5.4,
	Duel 		= 5.3,
	ArcheryAttack = 5.2,
	AmazingGrace = 5.1,
	Collateral 	= 5,
	FireAttack	=4.9
}

sgs.ai_chaofeng.huangyueying = 4

local zhiheng_skill = {}
zhiheng_skill.name = "zhiheng"
table.insert(sgs.ai_skills, zhiheng_skill)
zhiheng_skill.getTurnUseCard = function(self)
	if not self.player:hasUsed("ZhihengCard") then 
		return sgs.Card_Parse("@ZhihengCard=.")
	end
end

sgs.ai_skill_use_func.ZhihengCard = function(card, use, self)
	local unpreferedCards = {} 
	local cards = sgs.QList2Table(self.player:getHandcards())

	if self.player:getHp() < 3 then
		local zcards = self.player:getCards("he")
		local use_slash, keep_jink, keep_anal = false, false, false
		for _, zcard in sgs.qlist(zcards) do
			if not isCard("Peach", zcard, self.player) and not isCard("ExNihilo", zcard, self.player) then
				local shouldUse = true
				if not self:isWeak() and isCard("Slash", zcard, self.player) and not use_slash then
					local dummy_use = { isDummy = true }
					self:useBasicCard(zcard, dummy_use)
					if dummy_use.card then
						use_slash = true
						shouldUse = false
					end
				end
				if zcard:getTypeId() == sgs.Card_TypeTrick then
					local dummy_use = { isDummy = true }
					self:useTrickCard(zcard, dummy_use)
					if dummy_use.card then shouldUse = false end
				end
				if zcard:getTypeId() == sgs.Card_TypeEquip and not self.player:hasEquip(card) then
					local dummy_use = { isDummy = true }
					self:useEquipCard(zcard, dummy_use)
					if dummy_use.card then shouldUse = false end
				end
				if self.player:hasEquip(zcard) and zcard:isKindOf("Armor") and not self:needToThrowArmor() then shouldUse = false end
				if self.player:hasEquip(zcard) and zcard:isKindOf("DefensiveHorse") and not self:needToThrowArmor() then shouldUse = false end
				if isCard("Jink", zcard, self.player) and not keep_jink then
					keep_jink = true
					shouldUse = false
				end
				if self.player:getHp() == 1 and isCard("Analeptic", zcard, self.player) and not keep_anal then
					keep_anal = true
					shouldUse = false
				end
				if shouldUse then table.insert(unpreferedCards, zcard:getId()) end
			end
		end
	end

	if #unpreferedCards == 0 then
		local use_slash_num = 0
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if card:isKindOf("Slash") then
				local will_use = false
				if use_slash_num <= sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_Residue, self.player, card) then
					local dummy_use = { isDummy = true }
					self:useBasicCard(card, dummy_use)
					if dummy_use.card then
						will_use = true
						use_slash_num = use_slash_num + 1
					end
				end
				if not will_use then table.insert(unpreferedCards, card:getId()) end
			end
		end

		local num = self:getCardsNum("Jink") - 1
		if self.player:getArmor() then num = num + 1 end
		if num > 0 then
			for _, card in ipairs(cards) do
				if card:isKindOf("Jink") and num > 0 then
					table.insert(unpreferedCards, card:getId())
					num = num - 1
				end
			end
		end
		for _, card in ipairs(cards) do
			if (card:isKindOf("Weapon") and self.player:getHandcardNum() < 3) or card:isKindOf("OffensiveHorse")
				or self:getSameEquip(card, self.player) or card:isKindOf("AmazingGrace") then
				table.insert(unpreferedCards, card:getId())
			elseif card:getTypeId() == sgs.Card_TypeTrick then
				local dummy_use = { isDummy = true }
				self:useTrickCard(card, dummy_use)
				if not dummy_use.card then table.insert(unpreferedCards, card:getId()) end
			end
		end

		if self.player:getWeapon() and self.player:getHandcardNum() < 3 then
			table.insert(unpreferedCards, self.player:getWeapon():getId())
		end

		if self:needToThrowArmor() then
			table.insert(unpreferedCards, self.player:getArmor():getId())
		end

		if self.player:getOffensiveHorse() and self.player:getWeapon() then
			table.insert(unpreferedCards, self.player:getOffensiveHorse():getId())
		end
	end

	for index = #unpreferedCards, 1, -1 do
		if self.player:isJilei(sgs.Sanguosha:getCard(unpreferedCards[index])) then table.remove(unpreferedCards, index) end
	end

	if #unpreferedCards > 0 then
		use.card = sgs.Card_Parse("@ZhihengCard=" .. table.concat(unpreferedCards, "+"))
		return
	end
end

sgs.ai_use_value.ZhihengCard = 9
sgs.ai_use_priority.ZhihengCard = 2.61
sgs.dynamic_value.benefit.ZhihengCard = true
sgs.ai_chaofeng.sunquan = 2

function sgs.ai_cardneed.zhiheng(to, card)
	return not card:isKindOf("Jink")
end

local qixi_skill={}
qixi_skill.name="qixi"
table.insert(sgs.ai_skills,qixi_skill)
qixi_skill.getTurnUseCard=function(self,inclusive)
	local cards = self.player:getCards("he")
	cards=sgs.QList2Table(cards)
	
	local black_card
	
	self:sortByUseValue(cards,true)
	
	local has_weapon=false
	
	for _,card in ipairs(cards)  do
		if card:isKindOf("Weapon") and card:isBlack() then has_weapon=true end
	end
	
	for _,card in ipairs(cards)  do
		if card:isBlack()  and ((self:getUseValue(card)<sgs.ai_use_value.Dismantlement) or inclusive or self:getOverflow()>0) then
			local shouldUse=true

			if card:isKindOf("Armor") then
				if not self.player:getArmor() then shouldUse=false 
				elseif self:hasEquip(card) and not (card:isKindOf("SilverLion") and self.player:isWounded()) then shouldUse=false
				end
			end

			if card:isKindOf("Weapon") then
				if not self.player:getWeapon() then shouldUse=false
				elseif self:hasEquip(card) and not has_weapon then shouldUse=false
				end
			end
			
			if card:isKindOf("Slash") then
				local dummy_use = {isDummy = true}
				if self:getCardsNum("Slash") == 1 then
					self:useBasicCard(card, dummy_use)
					if dummy_use.card then shouldUse = false end
				end
			end

			if self:getUseValue(card) > sgs.ai_use_value.Dismantlement and card:isKindOf("TrickCard") then
				local dummy_use = {isDummy = true}
				self:useTrickCard(card, dummy_use)
				if dummy_use.card then shouldUse = false end
			end

			if shouldUse then
				black_card = card
				break
			end
			
		end
	end

	if black_card then
		local suit = black_card:getSuitString()
		local number = black_card:getNumberString()
		local card_id = black_card:getEffectiveId()
		local card_str = ("dismantlement:qixi[%s:%s]=%d"):format(suit, number, card_id)
		local dismantlement = sgs.Card_Parse(card_str)
		
		assert(dismantlement)

		return dismantlement
	end
end

sgs.qixi_suit_value = {
	spade = 3.9,
	club = 3.9
}

function sgs.ai_cardneed.qixi(to, card)
	return card:isBlack()
end

sgs.ai_chaofeng.ganning = 2

local kurou_skill={}
kurou_skill.name="kurou"
table.insert(sgs.ai_skills,kurou_skill)
kurou_skill.getTurnUseCard=function(self,inclusive)
	--特殊场景
	local func = Tactic("kurou", self, nil)
	if func then return func(self, nil) end
	--一般场景
	if (self.player:getHp() > 3 and self.player:getHandcardNum() > self.player:getHp())
		or (self.player:getHp() - self.player:getHandcardNum() >= 2) then
		return sgs.Card_Parse("@KurouCard=.")
	end
	local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)	
	if (self.player:getWeapon() and self.player:getWeapon():isKindOf("Crossbow")) or self:hasSkills("paoxiao") then
		for _, enemy in ipairs(self.enemies) do
			if self.player:canSlash(enemy, nil, true) and self:slashIsEffective(slash, enemy) 
			    and not (enemy:hasSkill("kongcheng") and enemy:isKongcheng())
				and not (self:hasSkills("fankui|guixin", enemy) and not self:hasSkills("paoxiao"))
				and not self:hasSkills("fenyong|jilei|zhichi", enemy)
				and sgs.isGoodTarget(enemy, self.enemies, self) and not self:slashProhibit(slash, enemy) and self.player:getHp()>1 then
				return sgs.Card_Parse("@KurouCard=.")
			end
		end
	end
	if self.player:getHp()==1 and self:getCardsNum("Analeptic")>=1 then
		return sgs.Card_Parse("@KurouCard=.")
	end
	
	--Suicide by Kurou
	local nextplayer = self.player:getNextAlive()
	if self.player:getHp()==1 and self.player:getRole()~="lord" and self.player:getRole()~="renegade" then
		local to_death = false
		if self:isFriend(nextplayer) then
			local yuejin = self.room:findPlayerBySkillName("gzxiaoguo")
			if yuejin and not self:isFriend(yuejin) and self.player:getEquips():isEmpty() 
				and not yuejin:isKongcheng() and self.player:getRole()=="rebel" then
				to_death = true
			end
			if not to_death and nextplayer:hasSkill("jieyin") and self.player:isMale() and (not nextplayer:containsTrick("indulgence") 
				or nextplayer:containsTrick("YanxiaoCard")) then
				return
			end
			if not to_death and nextplayer:hasSkill("qingnang") and (not nextplayer:containsTrick("indulgence") 
				or nextplayer:containsTrick("YanxiaoCard")) then
				return
			end
		end
		if self.player:getRole()=="rebel" and not self:isFriend(nextplayer) then
			if (not nextplayer:containsTrick("indulgence") or nextplayer:containsTrick("YanxiaoCard") 
				or nextplayer:hasSkill("shensu")) then
				to_death = true
			end
		end
		if self.player:getRole()=="loyalist" then
			local lord = self.room:getLord()
			if lord and lord:getCards("he"):isEmpty() then return end
			if self:isEnemy(nextplayer) and (not nextplayer:containsTrick("indulgence") or nextplayer:containsTrick("YanxiaoCard")) then
				if nextplayer:hasSkill("lijian") and self.player:isMale() and lord and lord:isMale() then
					to_death = true
				elseif nextplayer:hasSkill("quhu") and lord and lord:getHp() > nextplayer:getHp() and not lord:isKongcheng() 
					and lord:inMyAttackRange(self.player) then
					to_death = true
				end
			end
		end
		if to_death then
			local caopi = self.room:findPlayerBySkillName("xingshang")
			if caopi and self:isEnemy(caopi) then
				if self.player:getRole()=="rebel" and self.player:getHandcardNum() > 3 then
				elseif self.player:getRole()=="loyalist" and lord and lord:getCards("he"):length() > 3 then
				else to_death = false
				end
			end
		end
		if to_death then
			self.player:setFlags("Kurou_toDie")
			return sgs.Card_Parse("@KurouCard=.")
		end
		self.player:setFlags("-Kurou_toDie")
	end
end

sgs.ai_skill_use_func.KurouCard=function(card,use,self)
	if not use.isDummy then self:speak("kurou") end
	use.card=card
end

sgs.ai_use_priority.KurouCard = 6.8

sgs.ai_chaofeng.huanggai = 3

sgs.ai_skill_invoke.yingzi = function(self, data)
	if self.player:hasSkill("haoshi") then
		local num = self.player:getHandcardNum()
		local skills = self.player:getVisibleSkillList()
		local count = self:ImitateResult_DrawNCards(self.player, skills, self, false)
		if num + count > 5 then
			local others = self.room:getOtherPlayers(self.player)
			local least = 999
			local target = nil
			for _,p in sgs.qlist(others) do
				local handcardnum = p:getHandcardNum()
				if handcardnum < least then
					least = handcardnum
					target = p
				end
			end
			if target then
				if self:isFriend(target) then
					return not target:hasSkill("manjuan")
				end
			end
		end
	end
	return true
end

local fanjian_skill={}
fanjian_skill.name="fanjian"
table.insert(sgs.ai_skills,fanjian_skill)
fanjian_skill.getTurnUseCard=function(self)
	if self.player:isKongcheng() then return nil end
	if self.player:usedTimes("FanjianCard")>0 then return nil end

	local cards = self.player:getHandcards()

	for _, card in sgs.qlist(cards) do
		if card:getSuit() == sgs.Card_Diamond and self.player:getHandcardNum() == 1 then
			return nil
		elseif cards:length() <= 4 and (card:isKindOf("Peach") or card:isKindOf("Analeptic")) then
			return nil
		end
	end

	local card_str = "@FanjianCard=."
	local fanjianCard = sgs.Card_Parse(card_str)
	assert(fanjianCard)

	return fanjianCard		
end

sgs.ai_skill_use_func.FanjianCard=function(card,use,self)
	self:sort(self.enemies, "defense")
			
	for _, enemy in ipairs(self.enemies) do
		if self:canAttack(enemy) and not self:hasSkills("qingnang|jijiu|tianxiang",enemy) then
			use.card = card
			if use.to then use.to:append(enemy) end
			return
		end
	end
end

sgs.ai_card_intention.FanjianCard = 70

function sgs.ai_skill_suit.fanjian(self)
	local map = {0, 0, 1, 2, 2, 3, 3, 3}
	local suit = map[math.random(1, 8)]
	if self.player:hasSkill("hongyan") and suit == sgs.Card_Spade then return sgs.Card_Heart else return suit end
end

sgs.dynamic_value.damage_card.FanjianCard = true

sgs.ai_chaofeng.zhouyu = 3

sgs.ai_skill_invoke.lianying = function(self, data)
	if self:needKongcheng(self.player, true) then
		return player:getPhase() == sgs.Player_Play
	end
	return true
end

local guose_skill={}
guose_skill.name="guose"
table.insert(sgs.ai_skills,guose_skill)
guose_skill.getTurnUseCard=function(self,inclusive)
	local cards = self.player:getCards("he")
	cards=sgs.QList2Table(cards)
	
	local card
	
	self:sortByUseValue(cards,true)
	
	local has_weapon, has_armor = false, false
	
	for _,acard in ipairs(cards)  do
		if acard:isKindOf("Weapon") and not (acard:getSuit() == sgs.Card_Diamond) then has_weapon=true end
	end
	
	for _,acard in ipairs(cards)  do
		if acard:isKindOf("Armor") and not (acard:getSuit() == sgs.Card_Diamond) then has_armor=true end
	end
	
	for _,acard in ipairs(cards)  do
		if (acard:getSuit() == sgs.Card_Diamond) and ((self:getUseValue(acard)<sgs.ai_use_value.Indulgence) or inclusive) then
			local shouldUse=true
			
			if acard:isKindOf("Armor") then
				if not self.player:getArmor() then shouldUse=false 
				elseif self:hasEquip(acard) and not has_armor and self:evaluateArmor()>0 then shouldUse=false
				end
			end
			
			if acard:isKindOf("Weapon") then
				if not self.player:getWeapon() then shouldUse=false
				elseif self:hasEquip(acard) and not has_weapon then shouldUse=false
				end
			end
			
			if shouldUse then
				card = acard
				break
			end
		end
	end
	
	if not card then return nil end
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	local card_str = ("indulgence:guose[diamond:%s]=%d"):format(number, card_id)	
	local indulgence = sgs.Card_Parse(card_str)
	assert(indulgence)
	return indulgence	
end

function sgs.ai_cardneed.guose(to, card)
	return card:getSuit() == sgs.Card_Diamond
end

sgs.ai_skill_use["@@liuli"] = function(self, prompt)
	local others = self.room:getOtherPlayers(self.player)
	local slash = self.player:getTag("liuli-card"):toCard()
	others = sgs.QList2Table(others)
	local source
	for _, player in ipairs(others) do
		if player:hasFlag("slash_source") then
			source = player
			break
		end
	end
	self:sort(self.enemies, "defense")
	
	local doLiuli = function(who)
		if not self:isFriend(who) and who:hasSkill("leiji") 
			and ( self:hasSuit("spade", true, who) or who:getHandcardNum() >= 3)
			and (getKnownCard(who, "Jink", true) >= 1 or (not self:isEquip("QinggangSword", source) and self:isEquip("EightDiagram",who) )) then
			return "."
		end

		local cards = self.player:getCards("h")
		cards = sgs.QList2Table(cards)
		self:sortByKeepValue(cards)
		for _,card in ipairs(cards) do
			if self.player:distanceTo(who) <= self.player:getAttackRange() and not (who:hasSkill("kongcheng") and who:isKongcheng()) then
				if self:isFriend(who) and not (isCard("Peach", card, self.player) or isCard("Analeptic", card, self.player)) then
					return "@LiuliCard="..card:getEffectiveId().."->"..who:objectName()
				else
					return "@LiuliCard="..card:getEffectiveId().."->"..who:objectName()
				end
			end
		end

		local cards = self.player:getCards("e")
		cards=sgs.QList2Table(cards)
		self:sortByKeepValue(cards)
		for _,card in ipairs(cards) do
			if (self.player:getWeapon() and card:getId() == self.player:getWeapon():getId()) and self.player:distanceTo(who)>1 then				
			elseif card:isKindOf("OffensiveHorse") and self.player:getAttackRange()==self.player:distanceTo(who) and self.player:distanceTo(who,1)>1 then
			elseif self.player:inMyAttackRange(who) and not (who:hasSkill("kongcheng") and who:isKongcheng()) then
				return "@LiuliCard="..card:getEffectiveId().."->"..who:objectName()
			end
		end
		return "."
	end

	for _, enemy in ipairs(self.enemies) do
		if not (source and (source:objectName() == enemy:objectName())) then
			local ret = doLiuli(enemy)
			if ret ~= "." then return ret end
		end
	end

	for _, player in ipairs(others) do
		if self:objectiveLevel(player) == 0 and not (source and (source:objectName() == player:objectName())) then
			local ret = doLiuli(player)
			if ret ~= "." then return ret end
		end
	end


	self:sort(self.friends_noself, "defense")
	self.friends_noself = sgs.reverse(self.friends_noself)


	for _, friend in ipairs(self.friends_noself) do
		if not self:slashIsEffective(slash,friend) then
			if not (source and (source:objectName() == friend:objectName())) then
				local ret = doLiuli(friend)
				if ret ~= "." then return ret end
			end
		end
	end

	for _, friend in ipairs(self.friends_noself) do
		if self:needToLoseHp(friend, source, true) or self:getDamagedEffects(friend, source, true) then
			if not (source and (source:objectName() == friend:objectName())) then
				local ret = doLiuli(friend)
				if ret ~= "." then return ret end
			end
		end
	end

	if (self:isWeak() or self:hasHeavySlashDamage(source, slash)) and source:hasWeapon("Axe") and source:getCards("he"):length() > 2
	  and not self:getCardId("Peach") and not self:getCardId("Analeptic") then
		for _, friend in ipairs(self.friends_noself) do
			if not self:isWeak(friend) then
				if not (source and (source:objectName() == friend:objectName())) then
					local ret = doLiuli(friend)
					if ret ~= "." then return ret end
				end
			end
		end
	end

	if (self:isWeak() or self:hasHeavySlashDamage(source, slash)) and not self:getCardId("Jink") then
		for _, friend in ipairs(self.friends_noself) do
			if not self:isWeak(friend) then
				if not (source and (source:objectName() == friend:objectName())) then
					local ret = doLiuli(friend)
					if ret ~= "." then return ret end
				end
			end
		end
	end
	return "."
end

sgs.ai_card_intention.LiuliCard = function(self, card, from, to)
	sgs.ai_liuli_effect = true
end

function sgs.ai_slash_prohibit.liuli(self, to, card, from)
	if self:isFriend(to) then return false end
	if to:isNude() then return false end
	for _, friend in ipairs(self.friends_noself) do
		if to:canSlash(friend, card) and self:slashIsEffective(card, friend, nil, from) then return true end
	end
end

function sgs.ai_cardneed.liuli(to, card)
	return to:getCards("he"):length() <= 2 and not card:isKindOf("Jink")
end

sgs.guose_suit_value = {
	diamond = 3.9
}

sgs.ai_chaofeng.daqiao = 2

sgs.ai_chaofeng.luxun = -1

local jieyin_skill={}
jieyin_skill.name = "jieyin"
table.insert(sgs.ai_skills,jieyin_skill)
jieyin_skill.getTurnUseCard=function(self)
	if self.player:getHandcardNum() < 2 then return nil end
	if self.player:hasUsed("JieyinCard") then return nil end
	if self:needBear() and not self.player:isWounded() and self:isWeak() then return nil end
	
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	
	local first, second
	self:sortByUseValue(cards,true)
	for _, card in ipairs(cards) do
		if card:getTypeId() ~= sgs.Card_Equip then
			if not first then first  = cards[1]:getEffectiveId()
			else second = cards[2]:getEffectiveId()
			end
		end
		if second then break end
	end
	
	if not second then return end
	local card_str = ("@JieyinCard=%d+%d"):format(first, second)
	assert(card_str)
	return sgs.Card_Parse(card_str)
end


function SmartAI:getWoundedFriend(maleOnly)
	self:sort(self.friends, "hp")
	local list1 = {}	-- need help
	local list2 = {}	-- do not need help
	local addToList = function(p,index)
		if ( (not maleOnly) or (maleOnly and p:isMale()) ) and p:isWounded() then	
			table.insert(index ==1 and list1 or list2, p)
		end
	end

	local getCmpHp = function(p)
		local hp = p:getHp()
		if p:isLord() and self:isWeak(p) then hp = hp - 10 end
		if p:objectName() == self.player:objectName() and self:isWeak(p) and p:hasSkill("qingnang") then hp = hp - 5 end
		if p:hasSkill("buqu") and p:getPile("buqu"):length()<=2 then hp = hp + 5 end
		if self:hasSkills("rende|kuanggu|zaiqi", p) and p:getHp() >= 2 then hp = hp + 5 end
		return hp
	end


	local cmp = function (a ,b)
		if getCmpHp(a) == getCmpHp(b) then
			return sgs.getDefenseSlash(a) < sgs.getDefenseSlash(b)
		else
			return getCmpHp(a) < getCmpHp(b)
		end
	end

	for _, friend in ipairs(self.friends) do
		if friend:isLord() then
			if friend:getMark("hunzi") == 0 and friend:hasSkill("hunzi") 
					and self:getEnemyNumBySeat(self.player,friend) <= (friend:getHp()>= 2 and 1 or 0) then
				addToList(friend, 2)
			elseif self:needToLoseHp(friend, nil, nil, true, true) then
				addToList(friend, 2)
			elseif not sgs.isLordHealthy() then
				addToList(friend, 1)
			end
		else
			if self:needToLoseHp(friend, nil, nil, nil, true) or (self:hasSkills("rende|kuanggu|zaiqi", friend) and friend:getHp() >= 2) then
				addToList(friend, 2)
			else
				addToList(friend, 1)
			end
		end
	end
	table.sort(list1, cmp)
	table.sort(list2, cmp)
	return list1, list2
end

sgs.ai_skill_use_func.JieyinCard=function(card,use,self)
	local arr1,arr2 = self:getWoundedFriend(true)
	local target = nil
	
	repeat
		if #arr1>0 and (self:isWeak(arr1[1]) or self:isWeak() or self:getOverflow()>=1) then 
			target=arr1[1] 
			break
		end
		if #arr2>0 and self:isWeak() then 
			target=arr2[1] 
			break
		end
	until true

	if not target and self:isWeak() and self:getOverflow()>=2 and (self.role=="lord" or self.role=="renegade") then
		local others = self.room:getOtherPlayers(self.player)
		for _, other in sgs.qlist(others) do
			if other:isWounded() and other:isMale() then
				if (sgs.ai_chaofeng[other:getGeneralName()] or 0)<=2 and not self:hasSkills(sgs.masochism_skill, other) then
					target = other
					self.player:setFlags("jieyin_isenemy_"..other:objectName())
					break
				end
			end
		end
	end
	
	if target then
		use.card = card
		if use.to then use.to:append(target) end
		return
	end
end

sgs.ai_use_priority.JieyinCard = 2.8	-- 下调至决斗之后

sgs.ai_card_intention.JieyinCard = function(self, card, from, tos)
	if not from:hasFlag("jieyin_isenemy_"..tos[1]:objectName()) then 
		sgs.updateIntention(from, tos[1], -80)
	end
end

sgs.dynamic_value.benefit.JieyinCard = true

sgs.xiaoji_keep_value = {
	Peach = 6,
	Jink = 5.1,
	Weapon = 4.9,	
	Armor = 5,
	OffensiveHorse = 4.8,
	DefensiveHorse = 5
}

sgs.ai_chaofeng.sunshangxiang = 6

local qingnang_skill = {}
qingnang_skill.name = "qingnang"
table.insert(sgs.ai_skills, qingnang_skill)
qingnang_skill.getTurnUseCard = function(self)
	if self.player:getHandcardNum() < 1 then return nil end
	if self.player:usedTimes("QingnangCard") > 0 then return nil end
	
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)

	local compare_func = function(a, b)
		local v1 = self:getKeepValue(a) + ( a:isRed() and 50 or 0 ) + ( a:isKindOf("Peach") and 50 or 0 )
		local v2 = self:getKeepValue(b) + ( b:isRed() and 50 or 0 ) + ( b:isKindOf("Peach") and 50 or 0 )
		return v1 < v2
	end
	table.sort(cards, compare_func)

	local card_str = ("@QingnangCard=%d"):format(cards[1]:getId())
	return sgs.Card_Parse(card_str)
end

sgs.ai_skill_use_func.QingnangCard = function(card, use, self)
	local arr1, arr2 = self:getWoundedFriend()
	local target = nil	
	if #arr1 > 0 and (self:isWeak(arr1[1]) or self:getOverflow() >= 1) and not self:needToLoseHp(arr1[1], nil, nil, nil, true) then target = arr1[1] end
	if target then
		use.card = card
		if use.to then use.to:append(target) end 
		return
	end	
end

sgs.ai_use_priority.QingnangCard = 4.2
sgs.ai_card_intention.QingnangCard = -100

sgs.dynamic_value.benefit.QingnangCard = true

sgs.ai_view_as.jijiu = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card:isRed() and player:getPhase()==sgs.Player_NotActive then
		return ("peach:jijiu[%s:%s]=%d"):format(suit, number, card_id)
	end
end

sgs.jijiu_suit_value = {
	heart = 6,
	diamond = 6
}

sgs.ai_cardneed.jijiu = sgs.ai_cardneed.wusheng

sgs.ai_chaofeng.huatuo = 6

sgs.ai_skill_cardask["@wushuang-slash-1"] = function(self, data, pattern, target)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if self:canUseJieyuanDecrease(target) then return "." end
	if self:getCardsNum("Slash") < 2 and not (self.player:getHandcardNum() == 1 and self:hasSkills(sgs.need_kongcheng)) then return "." end
end

sgs.ai_skill_cardask["@wushuang-jink-1"] = function(self, data, pattern, target)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if self:canUseJieyuanDecrease(target) then return "." end	
	if self:hasSkill("kongcheng") then
		if target:hasWeapon("GudingBlade") and self.player:getHandcardNum() == 1 and self:getCardsNum("Jink") == 1 then return "." end
		if self.player:getHandcardNum() == 1 and self:getCardsNum("Jink") == 1 then return end
	else
		if not self:hasLoseHandcardEffective() and not self.player:isKongcheng() then return end
		if self:getCardsNum("Jink") < 2 then return "." end
	end
end

sgs.ai_chaofeng.lvbu = 1

local lijian_skill = {}
lijian_skill.name = "lijian"
table.insert(sgs.ai_skills, lijian_skill)
lijian_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("LijianCard") or self.player:isNude() then
		return 
	end	
	local card_id
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	local lightning = self:getCard("Lightning")

	if self:needToThrowArmor() then
		card_id = self.player:getArmor():getId()
	elseif self.player:getHandcardNum() > self.player:getHp() then			
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else	
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not acard:isKindOf("Peach") then 
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	elseif not self.player:getEquips():isEmpty() then
		local player = self.player
		if player:getWeapon() then card_id = player:getWeapon():getId()
		elseif player:getOffensiveHorse() then card_id = player:getOffensiveHorse():getId()
		elseif player:getDefensiveHorse() then card_id = player:getDefensiveHorse():getId()
		elseif player:getArmor() and player:getHandcardNum() <= 1 then card_id = player:getArmor():getId()
		end
	end
	if not card_id then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
				  and not acard:isKindOf("Peach") then 
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	end
	if not card_id then
		return nil
	else
		return sgs.Card_Parse("@LijianCard=" .. card_id)
	end
	return nil
end

sgs.ai_skill_use_func.LijianCard = function(card,use,self)
	local duel = sgs.Sanguosha:cloneCard("duel", sgs.Card_NoSuit, 0)
	local findFriend_maxSlash = function(self, first)
		self:log("Looking for the friend!")
		local maxSlash = 0
		local friend_maxSlash
		local nos_fazheng, fazheng
		for _, friend in ipairs(self.friends_noself) do
			if friend:isMale() and self:hasTrickEffective(duel, first, friend) then
				if friend:hasSkill("nosenyuan") and friend:getHp() > 1 then nos_fazheng = friend end
				if friend:hasSkill("enyuan") and friend:getHp() > 1 then fazheng = friend end
				if (getCardsNum("Slash", friend) > maxSlash) then
					maxSlash = getCardsNum("Slash", friend)
					friend_maxSlash = friend
				end
			end
		end

		if friend_maxSlash then
			local safe = false
			if self:hasSkills("ganglie|fankui|enyuan|neoganglie|nosenyuan", first) and not self:hasSkills("wuyan|noswuyan", first) then
				if (first:getHp() <= 1 and first:getHandcardNum() == 0) then safe = true end
			elseif (getCardsNum("Slash", friend_maxSlash) >= getCardsNum("Slash", first)) then safe = true end
			if safe then return friend_maxSlash end
		else self:log("unfound")
		end
		if nos_fazheng or fazheng then	return nos_fazheng or fazheng end		--备用友方，各种恶心的法正
		return nil
	end
	
	local lord = self.room:getLord()

	if self.role == "rebel" or (self.role == "renegade" and sgs.current_mode_players["loyalist"] + 1 > sgs.current_mode_players["rebel"]) then		
		
		if lord and lord:isMale() and not lord:isNude() then		-- 优先离间1血忠和主
			self:sort(self.enemies, "handcard")
			local e_peaches = 0
			local loyalist
			
			for _, enemy in ipairs(self.enemies) do
				e_peaches = e_peaches + getCardsNum("Peach", enemy)
				if enemy:getHp() == 1 and self:hasTrickEffective(duel, enemy, lord) and enemy:objectName() ~= lord:objectName()
				and enemy:isMale() and not loyalist then
					loyalist = enemy
				end
			end
			
			if loyalist and e_peaches < 1 then
				use.card = card
				if use.to then 
					use.to:append(loyalist)
					use.to:append(lord)
				end
				return
			end
		end
		
		if #self.friends_noself >= 2 and self:getAllPeachNum() < 1 then		--收友方反
			local nextplayerIsEnemy
			local nextp = self.player:getNextAlive()
			for i = 1, self.room:alivePlayerCount() do
				if not self:willSkipPlayPhase(nextp) then
					if not self:isFriend(nextp) then nextplayerIsEnemy = true end
					break
				else
					nextp = nextp:getNextAlive()
				end
			end	
			if nextplayerIsEnemy then
				local round = 50
				local to_die, nextfriend
				self:sort(self.enemies, "hp")
				
				for _, a_friend in ipairs(self.friends_noself) do	-- 目标1：寻找1血友方
					if a_friend:getHp() == 1 and a_friend:isKongcheng() and not self:hasSkills("kongcheng", a_friend) and a_friend:isMale() then
						for _, b_friend in ipairs(self.friends_noself) do		--目标2：寻找位于我之后，离我最近的友方
							if b_friend:objectName() ~= a_friend:objectName() and b_friend:isMale() and self:playerGetRound(b_friend) < round
							and self:hasTrickEffective(duel, a_friend, b_friend) then
							
								round = self:playerGetRound(b_friend)
								to_die = a_friend
								nextfriend = b_friend
								
							end
						end
						if to_die and nextfriend then break end
					end
				end
				
				if to_die and nextfriend then
					use.card = card
					if use.to then use.to:append(to_die) end
					if use.to then use.to:append(nextfriend) end
					return
				end
			end
		end
	end
	
	if lord and self:isFriend(lord) and lord:hasSkill("hunzi") and lord:getHp() == 2 and lord:getMark("hunzi") == 0 then
		local enemycount = self:getEnemyNumBySeat(self.player, lord)
		local peaches = self:getAllPeachNum()
		if peaches >= enemycount then
			local f_target, e_target
			for _, ap in sgs.qlist(self.room:getOtherPlayers(self.player)) do
				if ap:objectName() ~= lord:objectName() and ap:isMale() and self:hasTrickEffective(duel, lord, ap) then
					if self:hasSkills("jiang|jizhi", ap) and self:isFriend(ap) then
						use.card = card
						if use.to then
							use.to:append(lord)
							use.to:append(ap)
						end
						lord:setFlags("will_wake")
						return
					elseif self:isFriend(ap) then
						f_target = ap
					else
						e_target = ap
					end
				end
			end
			if f_target or e_target then
				local target = f_target or e_target
				use.card = card
				if use.to then 
					use.to:append(lord)
					use.to:append(target)
				end
				lord:setFlags("will_wake")
				return
			end
		end
	end

	local shenguanyu = self.room:findPlayerBySkillName("wuhun")
	if shenguanyu and shenguanyu:isMale() then
		if self.role == "rebel" and lord and lord:isMale() and not lord:hasSkill("jueqing") and self:hasTrickEffective(duel, shenguanyu, lord) then		
			use.card = card
			if use.to then 
				use.to:append(shenguanyu)
				use.to:append(lord)
			end
			return
			
		elseif self:isEnemy(shenguanyu) and #self.enemies >= 2 then
			for _, enemy in ipairs(self.enemies) do
				if enemy:objectName() ~= shenguanyu:objectName() and enemy:isMale() and self:hasTrickEffective(duel, shenguanyu, enemy) then
					use.card = card
					if use.to then
						use.to:append(shenguanyu)
						use.to:append(enemy)
					end
					return
				end
			end
		end
	end
	
	if not self.player:hasUsed("LijianCard") then
		self:sort(self.enemies, "defense")
		local males, others = {}, {}
		local first, second
		local zhugeliang_kongcheng, xunyu
		local duel = sgs.Sanguosha:cloneCard("duel", sgs.Card_NoSuit, 0)

		for _, enemy in ipairs(self.enemies) do
			if enemy:isMale() and not self:hasSkills("wuyan|noswuyan", enemy) then
				if enemy:hasSkill("kongcheng") and enemy:isKongcheng() then zhugeliang_kongcheng = enemy
				elseif enemy:hasSkill("jieming") then xunyu = enemy
				else
					for _, anotherenemy in ipairs(self.enemies) do
						if anotherenemy:isMale() and anotherenemy:objectName() ~= enemy:objectName() then
							if #males == 0 and self:hasTrickEffective(duel, enemy, anotherenemy) then
								if not (enemy:hasSkill("hunzi") and enemy:getMark("hunzi") < 1 and enemy:getHp() == 2) then
									table.insert(males, enemy)
								else
									table.insert(others, enemy)
								end
							end
							if #males == 1 and self:hasTrickEffective(duel, males[1], anotherenemy) then
								if not self:hasSkills("jizhi|jiang", anotherenemy) then
									table.insert(males, anotherenemy)
								else
									table.insert(others, anotherenemy)
								end
								if #males >= 2 then break end
							end
						end
					end
				end
				if #males >= 2 then break end
			end
		end
		
		if #males == 1 then
			if #others >= 1 then
				table.insert(males, others[1])
				
			elseif xunyu then
				if getCardsNum("Slash", males[1]) < 1 then
					table.insert(males, xunyu)
				else
					local drawcards = 0
					for _, enemy in ipairs(self.enemies) do
						local x = enemy:getMaxHp() > enemy:getHandcardNum() and math.min(5, enemy:getMaxHp() - enemy:getHandcardNum()) or 0
						if x > drawcards then drawcards = x end
					end
					if drawcards <= 2 then
						table.insert(males, xunyu)
					end
				end
			end
		end
		
		if #males == 1 and #self.friends_noself>0 then
			self:log("Only 1")
			first = males[1]
			if zhugeliang_kongcheng and self:hasTrickEffective(duel, first, zhugeliang_kongcheng) then
				table.insert(males, zhugeliang_kongcheng)
			else
				local friend_maxSlash = findFriend_maxSlash(self,first)
				if friend_maxSlash then table.insert(males, friend_maxSlash) end
			end
		end
		
		if #males >= 2 then
			first = males[1]
			second = males[2]
			local lord = self.room:getLord()
			if lord and first:getHp() <= 1 then
				if self.player:isLord() or sgs.isRolePredictable() then 
					local friend_maxSlash = findFriend_maxSlash(self,first)
					if friend_maxSlash then second=friend_maxSlash end
				elseif lord:isMale() and not self:hasSkills("wuyan|noswuyan", lord) then
					if self.role=="rebel" and not first:isLord() and self:hasTrickEffective(duel, first, lord) then
						second = lord
					else
						if ( (self.role == "loyalist" or self.role == "renegade") and not self:hasSkills("ganglie|enyuan|neoganglie|nosenyuan", first) )
							and ( getCardsNum("Slash", first) <= getCardsNum("Slash", second) ) then
							second = lord
						end
					end
				end
			end

			if first and second and first:objectName() ~= second:objectName() then
				use.card = card
				if use.to then 
					use.to:append(first)
					use.to:append(second)
				end
			end
		end
	end
end

sgs.ai_use_value.LijianCard = 8.5
sgs.ai_use_priority.LijianCard = 4

lijian_filter = function(player, carduse)
	if carduse.card:isKindOf("LijianCard") then
		sgs.ai_lijian_effect = true
	end
end

table.insert(sgs.ai_choicemade_filter.cardUsed, lijian_filter)

sgs.ai_card_intention.LijianCard = function(self,card, from, to)
	if sgs.evaluateRoleTrends(to[1]) == sgs.evaluateRoleTrends(to[2]) then
		if sgs.evaluateRoleTrends(from) == "rebel" and sgs.evaluateRoleTrends(to[1]) == sgs.evaluateRoleTrends(from) and to[1]:getHp() == 1 then
		elseif to[1]:hasSkill("hunzi") and to[1]:getHp() == 2 and to[1]:getMark("hunzi") == 0 then
		else
			sgs.updateIntentions(from, to, 40)
		end
	elseif sgs.evaluateRoleTrends(to[1]) ~= sgs.evaluateRoleTrends(to[2]) then
		sgs.updateIntention(from, to[1], 80)
	end	
end

sgs.dynamic_value.damage_card.LijianCard = true

sgs.ai_skill_invoke.biyue = function(self, data)
	if self:needKongcheng(self.player, true) then
		return false
	end
	return true
end
sgs.ai_chaofeng.diaochan = 4

sgs.ai_suit_priority.jijiu= "club|spade|diamond|heart"
sgs.ai_suit_priority.guose= "club|spade|heart|diamond"
sgs.ai_suit_priority.qixi= "diamond|heart|club|spade"
sgs.ai_suit_priority.qingguo= "diamond|heart|club|spade"
sgs.ai_suit_priority.wusheng= "club|spade|diamond|heart"

function SmartAI:canUseJieyuanDecrease(from, to)
	local to = to or self.player
	if not from then return false end
	if to:hasSkill("jieyuan") and from:getHp() >= to:getHp() then
		for _, card in sgs.qlist(to:getHandcards()) do
			if card:isRed() and not isCard("Peach", card, to) and not isCard("ExNihilo", card, to) then return true end
		end
	end
	return false
end
