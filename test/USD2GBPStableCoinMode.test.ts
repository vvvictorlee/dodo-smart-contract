/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

import { DODOContext, getDODOContext } from './utils/Context';
import { decimalStr, gweiStr } from './utils/Converter';
// const { parseLog } = require('ethereum-event-logs')
const parseLog = require('eth-log-parser');

const { abi } = require('../build/contracts/DODO.json')

// import * as assert from "assert"

let lp: string
let trader: string

async function init(ctx: DODOContext): Promise<void> {
    await ctx.setOraclePrice(decimalStr("0.74"))

    lp = ctx.spareAccounts[0]
    trader = ctx.spareAccounts[1]
    await ctx.approveDODO(lp)
    await ctx.approveDODO(trader)

    await ctx.mintTestToken(lp, decimalStr("1000000"), decimalStr("3000000"))
    await ctx.mintTestToken(trader, decimalStr("3000000"), decimalStr("3000000"))

    await ctx.DODO.methods.depositBase(decimalStr("1000000")).send(ctx.sendParam(lp))
    await ctx.DODO.methods.depositQuote(decimalStr("740000")).send(ctx.sendParam(lp))
    // await ctx.DODO.methods.depositQuote(decimalStr("740000")).send(ctx.sendParam(lp))
    // await ctx.DODO.methods.depositQuote(decimalStr("740000")).send(ctx.sendParam(lp))
    // await ctx.DODO.methods.withdrawQuote(decimalStr("740000")).send(ctx.sendParam(lp))
    // await ctx.DODO.methods.withdrawQuote(decimalStr("740000")).send(ctx.sendParam(lp))
}

describe("Trader", () => {

    let snapshotId: string
    let ctx: DODOContext

    before(async () => {
        let dodoContextInitConfig = {
            lpFeeRate: decimalStr("0.000595"),
            mtFeeRate: decimalStr("0.000105"),
            k: decimalStr("0.0001"), // nearly zero
            gasPriceLimit: gweiStr("100"),
        }
        ctx = await getDODOContext(dodoContextInitConfig)
        await init(ctx);
    })

    beforeEach(async () => {
        snapshotId = await ctx.EVM.snapshot();
    });

    afterEach(async () => {
        await ctx.EVM.reset(snapshotId)
    });

    describe("Trade stable coin", () => {
        // it("trade with tiny slippage", async () => {
        //     console.log("===_LP_FEE_RATE_====", await ctx.DODO.methods._LP_FEE_RATE_().call());
        //     console.log("===_MT_FEE_RATE_====", await ctx.DODO.methods._MT_FEE_RATE_().call());
        //     console.log("===_K_====", await ctx.DODO.methods._K_().call());

        //     // 10% depth avg price 1.000100000111135
        //     console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
        //     console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
        //     console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
        //     console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
        //     console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
        //     console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());



        //     await ctx.DODO.methods.buyBaseToken(decimalStr("1323.603731"), decimalStr("999.000000"), "0x").send(ctx.sendParam(trader))
        //     console.log(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("11000"))
        //     console.log(await ctx.QUOTE.methods.balanceOf(trader).call(), "8999899999888865431655")

        //     console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
        //     console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
        //     console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
        //     console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
        //     console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
        //     console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());

        //     //   // 99.9% depth avg price 1.00010109
        //     //   await ctx.DODO.methods.buyBaseToken(decimalStr("8990"), decimalStr("10000"), "0x").send(ctx.sendParam(trader))
        //     //   assert.equal(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("19990"))
        //     //   assert.equal(await ctx.QUOTE.methods.balanceOf(trader).call(), "8990031967806921648")

        //     // sell to 99.9% depth avg price 0.9999
        //     const receipt = await ctx.DODO.methods.sellBaseToken(decimalStr("998.500000"), decimalStr("728.900000"), "0x").send(ctx.sendParam(trader))
        //     console.log(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("10"))
        //     console.log(await ctx.QUOTE.methods.balanceOf(trader).call(), "19986992950440794518402")
        //     console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
        //     console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
        //     console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
        //     console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
        //     console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
        //     console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());


        //     // const receipt = /* execute tx on chain and wait for receipt */
        //     // console.log(JSON.stringify(receipt))
        //     // we can parse all events in the contract by passing through the ABI:
        //     // 
        //     {
        //         const events = parseLog(receipt.events.SellBaseToken.raw, abi)
        //         // const events = parseLog(Object.values(receipt.events), abi)
        //         console.log("=============================")

        //         console.log(events)
        //     }


        // })

        // it("trade with 1 tiny slippage", async () => {

        //     console.log("=============================")
        //     console.log("===_LP_FEE_RATE_====", await ctx.DODO.methods._LP_FEE_RATE_().call());
        //     console.log("===_MT_FEE_RATE_====", await ctx.DODO.methods._MT_FEE_RATE_().call());
        //     console.log("===_K_====", await ctx.DODO.methods._K_().call());

        //     // 10% depth avg price 1.000100000111135
        //     console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
        //     console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
        //     console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
        //     console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
        //     console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
        //     console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());



        //     await ctx.DODO.methods.buyBaseToken(decimalStr("1"), decimalStr("999.000000"), "0x").send(ctx.sendParam(trader))
        //     console.log(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("11000"))
        //     console.log(await ctx.QUOTE.methods.balanceOf(trader).call(), "8999899999888865431655")

        //     console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
        //     console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
        //     console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
        //     console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
        //     console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
        //     console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());

        //     //   // 99.9% depth avg price 1.00010109
        //     //   await ctx.DODO.methods.buyBaseToken(decimalStr("8990"), decimalStr("10000"), "0x").send(ctx.sendParam(trader))
        //     //   assert.equal(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("19990"))
        //     //   assert.equal(await ctx.QUOTE.methods.balanceOf(trader).call(), "8990031967806921648")

        //     // sell to 99.9% depth avg price 0.9999
        //     const receipt = await ctx.DODO.methods.sellBaseToken(decimalStr("1.00000"), decimalStr("0.100000"), "0x").send(ctx.sendParam(trader))
        //     console.log(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("10"))
        //     console.log(await ctx.QUOTE.methods.balanceOf(trader).call(), "19986992950440794518402")
        //     console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
        //     console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
        //     console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
        //     console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
        //     console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
        //     console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());


        //     // const receipt = /* execute tx on chain and wait for receipt */
        //     // console.log(JSON.stringify(receipt))
        //     // we can parse all events in the contract by passing through the ABI:
        //     // 
        //     {
        //         const events = parseLog(receipt.events.SellBaseToken.raw, abi)
        //         // const events = parseLog(Object.values(receipt.events), abi)
        //         console.log("=============================")

        //         console.log(events)
        //     }


        // })

        it.only("trade with 11 tiny slippage", async () => {
            // console.log("=============================")
            // console.log("===_LP_FEE_RATE_====", await ctx.DODO.methods._LP_FEE_RATE_().call());
            // console.log("===_MT_FEE_RATE_====", await ctx.DODO.methods._MT_FEE_RATE_().call());
            // console.log("===_K_====", await ctx.DODO.methods._K_().call());

            // // 10% depth avg price 1.000100000111135
            // console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
            // console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
            // console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
            // console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
            // console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
            // console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());



            // // await ctx.DODO.methods.buyBaseToken(decimalStr("1"), decimalStr("999.000000"), "0x").send(ctx.sendParam(trader))
            // console.log(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("11000"))
            // console.log(await ctx.QUOTE.methods.balanceOf(trader).call(), "8999899999888865431655")

            // console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
            // console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
            // console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
            // console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
            // console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
            // console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());

            // //   // 99.9% depth avg price 1.00010109
            // //   await ctx.DODO.methods.buyBaseToken(decimalStr("8990"), decimalStr("10000"), "0x").send(ctx.sendParam(trader))
            // //   assert.equal(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("19990"))
            // //   assert.equal(await ctx.QUOTE.methods.balanceOf(trader).call(), "8990031967806921648")

            // // sell to 99.9% depth avg price 0.9999
            // // const receipt = await ctx.DODO.methods.sellBaseToken(decimalStr("1.00000"), decimalStr("0.100000"), "0x").send(ctx.sendParam(trader))
            // console.log(await ctx.BASE.methods.balanceOf(trader).call(), decimalStr("10"))
            // console.log(await ctx.QUOTE.methods.balanceOf(trader).call(), "19986992950440794518402")
            // console.log("====_BASE_BALANCE_===", await ctx.DODO.methods._BASE_BALANCE_().call());
            // console.log("===_QUOTE_BALANCE_====", await ctx.DODO.methods._QUOTE_BALANCE_().call());
            // console.log("===_TARGET_BASE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_BASE_TOKEN_AMOUNT_().call());
            // console.log("===_TARGET_QUOTE_TOKEN_AMOUNT_====", await ctx.DODO.methods._TARGET_QUOTE_TOKEN_AMOUNT_().call());
            // console.log("===_R_STATUS_====", await ctx.DODO.methods._R_STATUS_().call());
            // console.log("====_ORACLE_===", await ctx.DODO.methods._ORACLE_().call());


            // _ORACLE_PRICE_: 0.74,
            // _LP_FEE_RATE_: 595,
            // _MT_FEE_RATE_: 105,
            // _K_: 100,
            // _R_STATUS_: 1,
            // _TARGET_BASE_TOKEN_AMOUNT_: '994984389360',
            // _TARGET_QUOTE_TOKEN_AMOUNT_: '739567295754',
            // _BASE_BALANCE_: '699279538448',
            // _QUOTE_BALANCE_: '958398324877'

            console.log("===buyBaseToken(decimalStr(698649.56)====", 699279538448 - (698649.56 + 698649.56 * 8 / (10 ** 4)));
            //    const receipt = await ctx.DODO.methods.buyBaseToken(decimalStr("1"), decimalStr("20000000"), "0x").send(ctx.sendParam(trader))

            const receipt = await ctx.DODO.methods.buyBaseToken(decimalStr("698649.56"), decimalStr("20000000"), "0x").send(ctx.sendParam(trader))

            // console.log("===queryBuyBaseToken====", await ctx.DODO.methods.queryBuyBaseToken(decimalStr("998649.56")).call());


            // const receipt:any= {};

            // const receipt = /* execute tx on chain and wait for receipt */
            // console.log(JSON.stringify(receipt))
            // we can parse all events in the contract by passing through the ABI:
            // 
            {
                const events = parseLog(receipt.events.BuyBaseToken.raw, abi)
                // const events = parseLog(Object.values(receipt.events), abi)
                console.log("=============================")

                console.log(events)
            }


        })







    })
})