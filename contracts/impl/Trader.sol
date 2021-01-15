/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {SafeMath} from "../lib/SafeMath.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";
import {Types} from "../lib/Types.sol";
import {IDODOCallee} from "../intf/IDODOCallee.sol";
import {Storage} from "./Storage.sol";
import {Pricing} from "./Pricing.sol";
import {Settlement} from "./Settlement.sol";

/**
 * @title Trader
 * @author DODO Breeder
 *
 * @notice Functions for trader operations
 */
contract Trader is Storage, Pricing, Settlement {
    using SafeMath for uint256;

    // ============ Events ============

    event SellBaseToken(
        address indexed seller,
        uint256 payBase,
        uint256 receiveQuote,
        uint256[] step
    );

    event BuyBaseToken(address indexed buyer, uint256 receiveBase, uint256 payQuote);

    event ChargeMaintainerFee(address indexed maintainer, bool isBaseToken, uint256 amount);

    // ============ Modifiers ============

    modifier tradeAllowed() {
        require(_TRADE_ALLOWED_, "TRADE_NOT_ALLOWED");
        _;
    }

    modifier buyingAllowed() {
        require(_BUYING_ALLOWED_, "BUYING_NOT_ALLOWED");
        _;
    }

    modifier sellingAllowed() {
        require(_SELLING_ALLOWED_, "SELLING_NOT_ALLOWED");
        _;
    }

    modifier gasPriceLimit() {
        require(tx.gasprice <= _GAS_PRICE_LIMIT_, "GAS_PRICE_EXCEED");
        _;
    }

    // ============ Trade Functions ============

    function sellBaseToken(
        uint256 amount,
        uint256 minReceiveQuote,
        bytes calldata data
    ) external tradeAllowed sellingAllowed gasPriceLimit preventReentrant returns (uint256) {
        // query price
        (
            uint256 receiveQuote,
            uint256 lpFeeQuote,
            uint256 mtFeeQuote,
            Types.RStatus newRStatus,
            uint256 newQuoteTarget,
            uint256 newBaseTarget,
            uint256[] memory steps
        ) = _querySellBaseToken(amount);
        require(receiveQuote >= minReceiveQuote, "SELL_BASE_RECEIVE_NOT_ENOUGH");

        // settle assets
        _quoteTokenTransferOut(msg.sender, receiveQuote);
        if (data.length > 0) {
            IDODOCallee(msg.sender).dodoCall(false, amount, receiveQuote, data);
        }
        _baseTokenTransferIn(msg.sender, amount);
        if (mtFeeQuote != 0) {
            _quoteTokenTransferOut(_MAINTAINER_, mtFeeQuote);
            emit ChargeMaintainerFee(_MAINTAINER_, false, mtFeeQuote);
        }

        // update TARGET
        if (_TARGET_QUOTE_TOKEN_AMOUNT_ != newQuoteTarget) {
            _TARGET_QUOTE_TOKEN_AMOUNT_ = newQuoteTarget;
        }
        if (_TARGET_BASE_TOKEN_AMOUNT_ != newBaseTarget) {
            _TARGET_BASE_TOKEN_AMOUNT_ = newBaseTarget;
        }
        if (_R_STATUS_ != newRStatus) {
            _R_STATUS_ = newRStatus;
        }

        _donateQuoteToken(lpFeeQuote);
        emit SellBaseToken(msg.sender, amount, receiveQuote, steps);

        return receiveQuote;
    }

    function buyBaseToken(
        uint256 amount,
        uint256 maxPayQuote,
        bytes calldata data
    ) external tradeAllowed buyingAllowed gasPriceLimit preventReentrant returns (uint256) {
        // uint256 baseBalance = _BASE_BALANCE_;

        // _ORACLE_PRICE_: 0.74,
        // _LP_FEE_RATE_: 595,
        // _MT_FEE_RATE_: 105,
        // _K_: 100,
        // require(false, append(uintToString(amount),"BuyBaseToken DODO_BASE_BALANCE_NOT_ENOUGH",uintToString(baseBalance),"",""));

        _R_STATUS_ = Types.RStatus.ABOVE_ONE; // uint256(1);
        _TARGET_BASE_TOKEN_AMOUNT_ = uint256(994984389360) * (10**12);
        _TARGET_QUOTE_TOKEN_AMOUNT_ = uint256(739567295754) * (10**12);
        _BASE_BALANCE_ = uint256(699279538448) * (10**12);
        _QUOTE_BALANCE_ = uint256(958398324877) * (10**12);
        // baseBalance = _BASE_BALANCE_;

        // require(false, append(uintToString(amount),"BuyBaseToken DODO_BASE_BALANCE_NOT_ENOUGH",uintToString(baseBalance),"",""));

        // query price
        (
            uint256 payQuote,
            uint256 lpFeeBase,
            uint256 mtFeeBase,
            Types.RStatus newRStatus,
            uint256 newQuoteTarget,
            uint256 newBaseTarget
        ) = _queryBuyBaseToken(amount);

        require(payQuote <= maxPayQuote, "BUY_BASE_COST_TOO_MUCH");

        // settle assets
        _baseTokenTransferOut(msg.sender, amount);
        if (data.length > 0) {
            IDODOCallee(msg.sender).dodoCall(true, amount, payQuote, data);
        }
        _quoteTokenTransferIn(msg.sender, payQuote);
        if (mtFeeBase != 0) {
            _baseTokenTransferOut(_MAINTAINER_, mtFeeBase);
            emit ChargeMaintainerFee(_MAINTAINER_, true, mtFeeBase);
        }

        // update TARGET
        if (_TARGET_QUOTE_TOKEN_AMOUNT_ != newQuoteTarget) {
            _TARGET_QUOTE_TOKEN_AMOUNT_ = newQuoteTarget;
        }
        if (_TARGET_BASE_TOKEN_AMOUNT_ != newBaseTarget) {
            _TARGET_BASE_TOKEN_AMOUNT_ = newBaseTarget;
        }
        if (_R_STATUS_ != newRStatus) {
            _R_STATUS_ = newRStatus;
        }

        _donateBaseToken(lpFeeBase);
        emit BuyBaseToken(msg.sender, amount, payQuote);

        return payQuote;
    }

    // ============ Query Functions ============

    function querySellBaseToken(uint256 amount) external view returns (uint256 receiveQuote) {
        (receiveQuote, , , , , , ) = _querySellBaseToken(amount);
        return receiveQuote;
    }

    function queryBuyBaseToken(uint256 amount) external view returns (uint256 payQuote) {
        (payQuote, , , , , ) = _queryBuyBaseToken(amount);
        return payQuote;
    }

    function _querySellBaseToken(uint256 amount)
        internal
        view
        returns (
            uint256 receiveQuote,
            uint256 lpFeeQuote,
            uint256 mtFeeQuote,
            Types.RStatus newRStatus,
            uint256 newQuoteTarget,
            uint256 newBaseTarget,
            uint256[] memory steps
        )
    {
        (newBaseTarget, newQuoteTarget, steps) = getExpectedTarget1();

        uint256 sellBaseAmount = amount;
        uint256 step = 0;
        if (_R_STATUS_ == Types.RStatus.ONE) {
            step = 1;
            // case 1: R=1
            // R falls below one
            receiveQuote = _ROneSellBaseToken(sellBaseAmount, newQuoteTarget);
            newRStatus = Types.RStatus.BELOW_ONE;
        } else if (_R_STATUS_ == Types.RStatus.ABOVE_ONE) {
            uint256 backToOnePayBase = newBaseTarget.sub(_BASE_BALANCE_);
            uint256 backToOneReceiveQuote = _QUOTE_BALANCE_.sub(newQuoteTarget);
            // case 2: R>1
            // complex case, R status depends on trading amount
            if (sellBaseAmount < backToOnePayBase) {
                step = backToOnePayBase;
                // case 2.1: R status do not change
                receiveQuote = _RAboveSellBaseToken(sellBaseAmount, _BASE_BALANCE_, newBaseTarget);
                newRStatus = Types.RStatus.ABOVE_ONE;
                if (receiveQuote > backToOneReceiveQuote) {
                    step = 211;
                    // [Important corner case!] may enter this branch when some precision problem happens. And consequently contribute to negative spare quote amount
                    // to make sure spare quote>=0, mannually set receiveQuote=backToOneReceiveQuote
                    receiveQuote = backToOneReceiveQuote;
                }
            } else if (sellBaseAmount == backToOnePayBase) {
                step = 22;
                // case 2.2: R status changes to ONE
                receiveQuote = backToOneReceiveQuote;
                newRStatus = Types.RStatus.ONE;
            } else {
                step = 23;
                // case 2.3: R status changes to BELOW_ONE
                receiveQuote = backToOneReceiveQuote.add(
                    _ROneSellBaseToken(sellBaseAmount.sub(backToOnePayBase), newQuoteTarget)
                );
                newRStatus = Types.RStatus.BELOW_ONE;
            }
        } else {
            step = 3;
            // _R_STATUS_ == Types.RStatus.BELOW_ONE
            // case 3: R<1
            receiveQuote = _RBelowSellBaseToken(sellBaseAmount, _QUOTE_BALANCE_, newQuoteTarget);
            newRStatus = Types.RStatus.BELOW_ONE;
        }

        // count fees
        lpFeeQuote = DecimalMath.mul(receiveQuote, _LP_FEE_RATE_);
        mtFeeQuote = DecimalMath.mul(receiveQuote, _MT_FEE_RATE_);
        receiveQuote = receiveQuote.sub(lpFeeQuote).sub(mtFeeQuote);
        steps[4] = step;
        return (
            receiveQuote,
            lpFeeQuote,
            mtFeeQuote,
            newRStatus,
            newQuoteTarget,
            newBaseTarget,
            steps
        );
    }

    function _queryBuyBaseToken(uint256 amount)
        internal
        view
        returns (
            uint256 payQuote,
            uint256 lpFeeBase,
            uint256 mtFeeBase,
            Types.RStatus newRStatus,
            uint256 newQuoteTarget,
            uint256 newBaseTarget
        )
    {
       


        (newBaseTarget, newQuoteTarget) = getExpectedTarget();



        // charge fee from user receive amount
        lpFeeBase = DecimalMath.mul(amount, _LP_FEE_RATE_);
        mtFeeBase = DecimalMath.mul(amount, _MT_FEE_RATE_);
        uint256 buyBaseAmount = amount.add(lpFeeBase).add(mtFeeBase);
 
        if (_R_STATUS_ == Types.RStatus.ONE) {
            // case 1: R=1
// require(
//             false,
//             append(
//                 uintToString(amount),
//                 "_queryBuyBaseToken 777 case 2: R>1 DODO_BASE_BALANCE_NOT_ENOUGH",
//                 uintToString(_BASE_BALANCE_),
//                 "",
//                 ""
//             )
//         );
            payQuote = _ROneBuyBaseToken(buyBaseAmount, newBaseTarget);
            newRStatus = Types.RStatus.ABOVE_ONE;
        } else if (_R_STATUS_ == Types.RStatus.ABOVE_ONE) {
            // case 2: R>1
// require(
//             false,
//             append(
//                 uintToString(amount),
//                 "_queryBuyBaseToken 44111556case 2: R>1 DODO_BASE_BALANCE_NOT_ENOUGH",
//                 uintToString(_BASE_BALANCE_),
//                 "",
//                 ""
//             )
//         );
            payQuote = _RAboveBuyBaseToken(buyBaseAmount, _BASE_BALANCE_, newBaseTarget);
            newRStatus = Types.RStatus.ABOVE_ONE;
        } else if (_R_STATUS_ == Types.RStatus.BELOW_ONE) {
            uint256 backToOnePayQuote = newQuoteTarget.sub(_QUOTE_BALANCE_);
            uint256 backToOneReceiveBase = _BASE_BALANCE_.sub(newBaseTarget);
            // case 3: R<1
            // complex case, R status may change
            if (buyBaseAmount < backToOneReceiveBase) {
                // case 3.1: R status do not change
                // no need to check payQuote because spare base token must be greater than zero
                payQuote = _RBelowBuyBaseToken(buyBaseAmount, _QUOTE_BALANCE_, newQuoteTarget);
                newRStatus = Types.RStatus.BELOW_ONE;
            } else if (buyBaseAmount == backToOneReceiveBase) {
                // case 3.2: R status changes to ONE
                payQuote = backToOnePayQuote;
                newRStatus = Types.RStatus.ONE;
            } else {
                // case 3.3: R status changes to ABOVE_ONE
                payQuote = backToOnePayQuote.add(
                    _ROneBuyBaseToken(buyBaseAmount.sub(backToOneReceiveBase), newBaseTarget)
                );
                newRStatus = Types.RStatus.ABOVE_ONE;
            }
        }

        return (payQuote, lpFeeBase, mtFeeBase, newRStatus, newQuoteTarget, newBaseTarget);
    }
}
