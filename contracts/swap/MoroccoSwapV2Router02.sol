// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import './libraries/MoroccoSwapV2Library.sol';
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IMoroccoSwapV2Router02.sol';
import './interfaces/IMoroccoSwapV2Factory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './MoroccoSwapFeeTransfer.sol';


contract MoroccoSwapV2Router02 is IMoroccoSwapV2Router02 {
    using SafeMathMoroccoSwap for uint;

    address public immutable override factory;
    address public immutable override WETH;
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'MoroccoSwapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
     }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IMoroccoSwapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IMoroccoSwapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = MoroccoSwapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MoroccoSwapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MoroccoSwapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = MoroccoSwapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MoroccoSwapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = MoroccoSwapV2Library.pairFor(factory, tokenA, tokenB);
        (amountA, amountB) = takeAddLiquidityFee(tokenA, tokenB, amountA, amountB, false);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IMoroccoSwapV2Pair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = MoroccoSwapV2Library.pairFor(factory, token, WETH);
        IWETH(WETH).deposit{value: amountETH}();        
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        
        (amountToken, amountETH) = takeAddLiquidityFee(token, WETH, amountToken, amountETH, true);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
       
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IMoroccoSwapV2Pair(pair).mint(to);      
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = MoroccoSwapV2Library.pairFor(factory, tokenA, tokenB);
        IMoroccoSwapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IMoroccoSwapV2Pair(pair).burn(to);
        (address token0,) = MoroccoSwapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if(amountAMin > 0){
            amountAMin = amountAMin.sub(amountAMin.mul(IMoroccoSwapV2Factory(factory).InOutTotalFee()).div(IMoroccoSwapV2Factory(factory).PERCENT100()));
        }
        if(amountBMin > 0){
            amountBMin = amountBMin.sub(amountBMin.mul(IMoroccoSwapV2Factory(factory).InOutTotalFee()).div(IMoroccoSwapV2Factory(factory).PERCENT100()));
        }
        require(amountA >= amountAMin, 'MoroccoSwapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'MoroccoSwapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = MoroccoSwapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IMoroccoSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = MoroccoSwapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IMoroccoSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = MoroccoSwapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IMoroccoSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MoroccoSwapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? MoroccoSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IMoroccoSwapV2Pair(MoroccoSwapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amountIn  = takeSwapFee(path[0], path[1], amountIn, false);
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }


    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        takeSwapFee(path[0], path[1], amountInMax, false);
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MoroccoSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }


    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        uint256 msgvalue = msg.value;
        IWETH(WETH).deposit{value: msgvalue}();
        msgvalue = takeSwapFee(path[0], path[1], msgvalue, true);
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, msgvalue, path);        
        require(amounts[amounts.length - 1] >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');      
        assert(IWETH(WETH).transfer(MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        takeSwapFee(path[0], path[1], amountInMax, false);
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MoroccoSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        amountIn = takeSwapFee(path[0], path[1], amountIn, false);
        amounts = MoroccoSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        uint256 msgValue = msg.value;
        IWETH(WETH).deposit{value: msgValue}();
        msgValue = takeSwapFee(path[0], path[1], msgValue, true);
        amounts = MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'MoroccoSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        assert(IWETH(WETH).transfer(MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        uint256 sfee = msg.value.sub(msgValue);
        if (msg.value > amounts[0].add(sfee)) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0].add(sfee));
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MoroccoSwapV2Library.sortTokens(input, output);
            IMoroccoSwapV2Pair pair = IMoroccoSwapV2Pair(MoroccoSwapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = MoroccoSwapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? MoroccoSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        amountIn = takeSwapFee(path[0], path[1], amountIn, false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        amountIn = takeSwapFee(path[0], path[1], amountIn, true);
        assert(IWETH(WETH).transfer(MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'MoroccoSwapV2Router: INVALID_PATH');
        amountIn = takeSwapFee(path[0], path[1], amountIn, false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MoroccoSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'MoroccoSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return MoroccoSwapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return MoroccoSwapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return MoroccoSwapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return MoroccoSwapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return MoroccoSwapV2Library.getAmountsIn(factory, amountOut, path);
    }

    function takeAddLiquidityFee(address _token0, address _token1, uint256 _amount0, uint256 _amount1, bool isEth) internal returns(uint256, uint256){
       if(IMoroccoSwapV2Factory(factory).pause() == false){
           
            uint256 PERCENT = IMoroccoSwapV2Factory(factory).PERCENT100();         
            uint256 _totalFees = IMoroccoSwapV2Factory(factory).InoutTax();                    
            uint256 _totalFees0 = _amount0.mul(_totalFees).div(PERCENT);             
            uint256 _totalFees1 =  _amount1.mul(_totalFees).div(PERCENT);
            address feeTransfer = IMoroccoSwapV2Factory(factory).feeTransfer();

            TransferHelper.safeTransferFrom(_token0, msg.sender, feeTransfer, _totalFees0);
            if(!isEth){
                TransferHelper.safeTransferFrom(_token1, msg.sender, feeTransfer, _totalFees1);
            }else{
                TransferHelper.safeTransfer(_token1, feeTransfer, _totalFees1);
            }
           
            MoroccoSwapFeeTransfer(feeTransfer).takeLiquidityFee(_token0, _token1, _amount0, _amount1);
            _amount0 = _amount0.sub(_totalFees0);
            _amount1 = _amount1.sub(_totalFees1);
            return(_amount0, _amount1);
       }else{
           return(_amount0, _amount1);
       }
    }

   function takeSwapFee(address token, address token1, uint256 amount, bool isEth) internal returns(uint256){
        if(IMoroccoSwapV2Factory(factory).pause() == false){
            uint256 PERCENT100 = IMoroccoSwapV2Factory(factory).PERCENT100();            
            uint256 totalFees = amount.mul(IMoroccoSwapV2Factory(factory).swapTax()).div(PERCENT100);

            if(isEth){
                TransferHelper.safeTransfer(token, IMoroccoSwapV2Factory(factory).feeTransfer(), totalFees);
            }else {
                TransferHelper.safeTransferFrom(token, msg.sender,IMoroccoSwapV2Factory(factory).feeTransfer(), totalFees);
            }
            MoroccoSwapFeeTransfer(IMoroccoSwapV2Factory(factory).feeTransfer()).takeSwapFee(
                            MoroccoSwapV2Library.pairFor(factory, token, token1), token,amount);
            amount = amount.sub(totalFees);
            return amount;
        }else{
            return amount;
       }
    }

}
