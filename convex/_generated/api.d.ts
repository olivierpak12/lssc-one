/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as Backfillamountusd from "../Backfillamountusd.js";
import type * as admin from "../admin.js";
import type * as adminActions from "../adminActions.js";
import type * as adminQueries from "../adminQueries.js";
import type * as balances from "../balances.js";
import type * as bikes from "../bikes.js";
import type * as deposits from "../deposits.js";
import type * as email from "../email.js";
import type * as etherscanActions from "../etherscanActions.js";
import type * as http from "../http.js";
import type * as init from "../init.js";
import type * as lib_rpcHelpers from "../lib/rpcHelpers.js";
import type * as messages from "../messages.js";
import type * as networks from "../networks.js";
import type * as password from "../password.js";
import type * as recoverTokensAction from "../recoverTokensAction.js";
import type * as referrals from "../referrals.js";
import type * as reports from "../reports.js";
import type * as resetPassword from "../resetPassword.js";
import type * as seedBscNetwork from "../seedBscNetwork.js";
import type * as sweepActions from "../sweepActions.js";
import type * as sweep_transactions from "../sweep_transactions.js";
import type * as teams from "../teams.js";
import type * as users from "../users.js";
import type * as walletActions from "../walletActions.js";
import type * as wallets from "../wallets.js";
import type * as withdrawalActions from "../withdrawalActions.js";
import type * as withdrawals from "../withdrawals.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  Backfillamountusd: typeof Backfillamountusd;
  admin: typeof admin;
  adminActions: typeof adminActions;
  adminQueries: typeof adminQueries;
  balances: typeof balances;
  bikes: typeof bikes;
  deposits: typeof deposits;
  email: typeof email;
  etherscanActions: typeof etherscanActions;
  http: typeof http;
  init: typeof init;
  "lib/rpcHelpers": typeof lib_rpcHelpers;
  messages: typeof messages;
  networks: typeof networks;
  password: typeof password;
  recoverTokensAction: typeof recoverTokensAction;
  referrals: typeof referrals;
  reports: typeof reports;
  resetPassword: typeof resetPassword;
  seedBscNetwork: typeof seedBscNetwork;
  sweepActions: typeof sweepActions;
  sweep_transactions: typeof sweep_transactions;
  teams: typeof teams;
  users: typeof users;
  walletActions: typeof walletActions;
  wallets: typeof wallets;
  withdrawalActions: typeof withdrawalActions;
  withdrawals: typeof withdrawals;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
