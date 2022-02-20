pragma solidity 0.6.12;

import "./interfaces/IMoroccoSwapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IBank.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";

contract MoroccoSwapFeeTransfer {
    using SafeMathMoroccoSwap for uint256;

    uint256 public constant PERCENT100 = 1000000;
    address
        public constant DEADADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public factory;
    address public router;

    // Global recevier address
    address public global;
    address public roulette;
    address public farm;
    // Bank address
    address public kythBank;
    address public usdtxBank;
    address public goldxBank;
    address public btcxBank;
    address public ethxBank;
    //Inout fee
    uint256 public bankFee = 1000;
    uint256 public globalFee = 7000;
    uint256 public rouletteFee = 500;
    uint256 public totalFee = 12500;

    // Swap fee
    uint256 public sfarmFee = 900;
    uint256 public sUSDTxFee = 50;
    uint256 public sglobalFee = 950;
    uint256 public srouletteFee = 100;
    uint256 public sLockFee = 500;
    uint256 public swaptotalFee = 2500;

    address public feeSetter;

    constructor(
        address _factory,
        address _router,
        address _feeSetter
    ) public {
        factory = _factory;
        router = _router;
        feeSetter = _feeSetter;
    }

    function takeSwapFee(
        address lp,
        address token,
        uint256 amount
    ) public returns (uint256) {
        uint256 PERCENT = PERCENT100;
        uint256 _sFarmFee = amount.mul(sfarmFee).div(PERCENT);
        uint256 _sUSDTxFee = amount.mul(sUSDTxFee).div(PERCENT);
        uint256 _sGlobalFee = amount.mul(sglobalFee).div(PERCENT);
        uint256 _sRouletteFee = amount.mul(srouletteFee).div(PERCENT);
        uint256 _sLockFee = amount.mul(sLockFee).div(PERCENT);

        TransferHelper.safeTransfer(token, DEADADDRESS, _sLockFee);

        _approvetokens(token, farm, amount);
        IFarm(farm).addrewardtoken(lp, token, _sFarmFee);

        TransferHelper.safeTransfer(token, global, _sGlobalFee);
        TransferHelper.safeTransfer(token, roulette, _sRouletteFee);

        _approvetokens(token, usdtxBank, amount);
        IBank(usdtxBank).addrewardtoken(token, _sUSDTxFee);
    }

    function takeLiquidityFee(
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1
    ) public {
        uint256 PERCENT = PERCENT100;

        address[5] memory bankFarm = [
            kythBank,
            usdtxBank,
            goldxBank,
            btcxBank,
            ethxBank
        ];

        uint256[3] memory bankFee0;
        bankFee0[0] = _amount0.mul(bankFee).div(PERCENT);
        bankFee0[1] = _amount0.mul(globalFee).div(PERCENT); //globalFee0
        bankFee0[2] = _amount0.mul(rouletteFee).div(PERCENT); //rouletteFee0

        uint256[3] memory bankFee1;
        bankFee1[0] = _amount1.mul(bankFee).div(PERCENT);
        bankFee1[1] = _amount1.mul(globalFee).div(PERCENT); //globalFee1
        bankFee1[2] = _amount1.mul(rouletteFee).div(PERCENT); //rouletteFee1

        TransferHelper.safeTransfer(_token0, global, bankFee0[1]);
        TransferHelper.safeTransfer(_token1, global, bankFee1[1]);

        TransferHelper.safeTransfer(_token0, roulette, bankFee0[2]);
        TransferHelper.safeTransfer(_token1, roulette, bankFee1[2]);

        _approvetoken(_token0, _token1, bankFarm[0], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[1], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[2], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[3], _amount0, _amount1);
        _approvetoken(_token0, _token1, bankFarm[4], _amount0, _amount1);

        IBank(bankFarm[0]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[1]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[2]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[3]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
        IBank(bankFarm[4]).addReward(
            _token0,
            _token1,
            bankFee0[0],
            bankFee1[0]
        );
    }

    function _approvetoken(
        address _token0,
        address _token1,
        address _receiver,
        uint256 _amount0,
        uint256 _amount1
    ) private {
        if (
            _token0 != address(0x000) ||
            IERC20(_token0).allowance(address(this), _receiver) < _amount0
        ) {
            IERC20(_token0).approve(_receiver, _amount0);
        }
        if (
            _token1 != address(0x000) ||
            IERC20(_token1).allowance(address(this), _receiver) < _amount1
        ) {
            IERC20(_token1).approve(_receiver, _amount1);
        }
    }

    function _approvetokens(
        address _token,
        address _receiver,
        uint256 _amount
    ) private {
        if (
            _token != address(0x000) ||
            IERC20(_token).allowance(address(this), _receiver) < _amount
        ) {
            IERC20(_token).approve(_receiver, _amount);
        }
    }

    function configure(
        address _global,
        address _roulette,
        address _farm,
        address _kythBank,
        address _usdtxBank,
        address _goldxBank,
        address _btcxBank,
        address _ethxBank
    ) external {
        require(msg.sender == feeSetter, "Only fee setter");

        global = _global;
        roulette = _roulette;
        farm = _farm;
        kythBank = _kythBank;
        usdtxBank = _usdtxBank;
        goldxBank = _goldxBank;
        btcxBank = _btcxBank;
        ethxBank = _ethxBank;
    }
}
