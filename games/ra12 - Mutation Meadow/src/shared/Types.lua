-- Shared types: the saved profile (the §4 schema plus the safety fields).

export type TileId = string -- "1".."64" (row-major in an 8x8 grid) or "extra1".."extra8"
export type MutSet = { wet: boolean?, golden: boolean? }
export type Tile = {
	seed: string,
	plantedAt: number,
	grown: number, -- grown = boosted seconds accrued
	harvestsLeft: number,
	muts: MutSet,
	canUsed: boolean,
}
export type Item = {
	seed: string,
	muts: MutSet,
	foundAt: number,
	foundBy: number,
	owner: number,
	locked: boolean, -- locked while on a pedestal or in a pending gift
	giftedBy: number?,
}
export type Profile = {
	v: number,
	coins: number,
	lifetimeCoins: number,
	lock: { jobId: string, at: number }?, -- nil when released
	seeds: { [string]: number },
	plotLevel: number,
	can: "tin" | "copper" | "silver",
	sprinklers: { basic: number, advanced: number, placed: { [TileId]: "basic" | "advanced" } },
	tiles: { [TileId]: Tile },
	basket: { [string]: number },
	autoSell: boolean,
	gnomeOn: boolean,
	items: { [string]: Item }, -- key = GUID
	pedestals: { [string]: string }, -- "1".."7" -> GUID (string keys: no sparse arrays)
	collection: {
		found: { [string]: { at: number, n: number } }, -- "seed:wet|golden|wetgolden"
		claimed: { [string]: boolean },
		milestones: { [string]: boolean },
	},
	restock: { slot: number, bought: { [string]: number } },
	passes: { [string]: boolean }, -- granted by gift product; game-pass ownership is checked live
	cosmetics: {
		owned: { [string]: boolean },
		equipped: { theme: string?, trail: string?, tag: string?, can: string? },
	},
	daily: { day: number, lastClaimDay: number, streak: number, cycle: number }, -- day 1..7; UTC day numbers
	quests: {
		starter: { [string]: { n: number, claimed: boolean } },
		daily: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
	},
	playtime: { day: number, sec: number, claimed: { [string]: boolean } }, -- "1".."3"
	social: {
		day: number,
		helps: number,
		itemGifts: number,
		liked: { [string]: boolean },
		likesReceived: number, -- likesReceived: eng (M9)
	},
	weekly: { claimed: { [string]: boolean }, lineSeen: string? }, -- updateId "YYYY-MM-DD"
	blockParty: { window: number, waters: number, rewarded: boolean, rewardsTotal: number },
	badges: { [string]: boolean },
	patchTips: { plant: boolean, shopHello: boolean, shower: boolean, mutation: boolean, blockParty: boolean },
	settings: { patchAlerts: boolean, music: boolean, sfx: boolean, reducedFx: boolean, gardenName: string? },
	firstSession: {
		done: boolean,
		playedSec: number,
		showerDone: boolean,
		showerAt: number?,
		wetGuaranteed: boolean,
		calendarShown: boolean,
		extraRowEligible: boolean,
	},
	receipts: { string }, -- last 50 PurchaseIds
	giftsIn: { string }, -- last 100 applied gift purchaseIds
	outbox: { [string]: { guid: string, toId: number, item: Item, at: number } }, -- pending item gifts
	meta: {
		created: number,
		lastSeen: number,
		sessionStart: number,
		source: string?, -- acquisition tag, set once (M10)
		campaign: string?,
		growCredits: number, -- eng (M9 Instant Grow with nothing growing)
		bundleGrants: { string }?, -- eng (M9 resolved Starter Bundle contents, fixed once; meta.bundleGrants)
		pendingGifts: { { key: string, friendId: number, at: number } }, -- eng: one slot per gift prompt, oldest first
		pendingGift: { key: string, friendId: number, at: number }?, -- eng (M9, read once and moved into pendingGifts)
	},
}

export type Gift = { purchaseId: string, key: string, fromId: number, at: number }

return {}
