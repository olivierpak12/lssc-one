import { mutation } from "./_generated/server";

// ─── One-time backfill — deposits ────────────────────────────────────────────
// Safe to re-run — skips records that already have amountUsd set.

export const backfillDepositsAmountUsd = mutation({
  args: {},
  handler: async (ctx): Promise<{ message: string; updated: number; skipped: number }> => {
    const deposits = await ctx.db.query("deposits").collect();
    let updated = 0;
    let skipped = 0;

    for (const deposit of deposits) {
      if ((deposit as any).amountUsd !== undefined) { skipped++; continue; }
      try {
        const amountUsd = Number(BigInt(deposit.amount)) / 1_000_000;
        await ctx.db.patch(deposit._id, { amountUsd } as any);
        updated++;
      } catch (err) {
        console.error(`Failed to patch deposit ${deposit._id}: ${err}`);
        skipped++;
      }
    }

    return { message: "Deposits backfill complete.", updated, skipped };
  },
});

// ─── One-time backfill — withdrawals ─────────────────────────────────────────
// withdrawal.amount is net of fee — that's correct, it's what the user received.

export const backfillWithdrawalsAmountUsd = mutation({
  args: {},
  handler: async (ctx): Promise<{ message: string; updated: number; skipped: number }> => {
    const withdrawals = await ctx.db.query("withdrawals").collect();
    let updated = 0;
    let skipped = 0;

    for (const withdrawal of withdrawals) {
      if ((withdrawal as any).amountUsd !== undefined) { skipped++; continue; }
      try {
        const amountUsd = Number(BigInt(withdrawal.amount)) / 1_000_000;
        await ctx.db.patch(withdrawal._id, { amountUsd } as any);
        updated++;
      } catch (err) {
        console.error(`Failed to patch withdrawal ${withdrawal._id}: ${err}`);
        skipped++;
      }
    }

    return { message: "Withdrawals backfill complete.", updated, skipped };
  },
});

// ─── One-time backfill — balances ────────────────────────────────────────────
// Converts balance.amount (string as micros) to amountUsd (number).

export const backfillBalancesAmountUsd = mutation({
  args: {},
  handler: async (ctx): Promise<{ message: string; updated: number; skipped: number }> => {
    const balances = await ctx.db.query("balances").collect();
    let updated = 0;
    let skipped = 0;

    for (const balance of balances) {
      if ((balance as any).amountUsd !== undefined) { skipped++; continue; }
      try {
        const amountUsd = Number(BigInt(balance.amount)) / 1_000_000;
        await ctx.db.patch(balance._id, { amountUsd } as any);
        updated++;
      } catch (err) {
        console.error(`Failed to patch balance ${balance._id}: ${err}`);
        skipped++;
      }
    }

    return { message: "Balances backfill complete.", updated, skipped };
  },
});

// ─── Run both at once ────────────────────────────────────────────────────────
// Call backfillAll({}) to do deposits + withdrawals in one shot.

export const backfillAll = mutation({
  args: {},
  handler: async (ctx): Promise<{
    deposits: { updated: number; skipped: number };
    withdrawals: { updated: number; skipped: number };
  }> => {
    const deposits = await ctx.db.query("deposits").collect();
    const withdrawals = await ctx.db.query("withdrawals").collect();

    let dUpdated = 0; let dSkipped = 0;
    let wUpdated = 0; let wSkipped = 0;

    for (const deposit of deposits) {
      if ((deposit as any).amountUsd !== undefined) { dSkipped++; continue; }
      try {
        await ctx.db.patch(deposit._id, { amountUsd: Number(BigInt(deposit.amount)) / 1_000_000 } as any);
        dUpdated++;
      } catch { dSkipped++; }
    }

    for (const withdrawal of withdrawals) {
      if ((withdrawal as any).amountUsd !== undefined) { wSkipped++; continue; }
      try {
        await ctx.db.patch(withdrawal._id, { amountUsd: Number(BigInt(withdrawal.amount)) / 1_000_000 } as any);
        wUpdated++;
      } catch { wSkipped++; }
    }

    return {
      deposits: { updated: dUpdated, skipped: dSkipped },
      withdrawals: { updated: wUpdated, skipped: wSkipped },
    };
  },
});

// ─── One-time backfill — pendingAdminWithdrawals ──────────────────────────────

export const backfillPendingAdminWithdrawalsAmountUsd = mutation({
  args: {},
  handler: async (ctx): Promise<{ message: string; updated: number; skipped: number }> => {
    const records = await ctx.db.query("pendingAdminWithdrawals").collect();
    let updated = 0;
    let skipped = 0;

    for (const record of records) {
      if ((record as any).amountUsd !== undefined) { skipped++; continue; }
      try {
        const amountUsd = Number(BigInt(record.amount)) / 1_000_000;
        await ctx.db.patch(record._id, { amountUsd } as any);
        updated++;
      } catch (err) {
        console.error(`Failed to patch pendingAdminWithdrawal ${record._id}: ${err}`);
        skipped++;
      }
    }

    return { message: "Pending admin withdrawals backfill complete.", updated, skipped };
  },
});