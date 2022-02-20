pragma solidity 0.6.12;
import "./IERC20.sol";


interface IBank{
    function addReward(address token0, address token1, uint256 amount0, uint256 amount1) external;
     function addrewardtoken(
        address token,
        uint256 amount
    ) external;
}

interface IFarm{
    
     function addLPInfo(
        IERC20 _lpToken,
        IERC20 _rewardToken0,
        IERC20 _rewardToken1
    ) external;

    function addReward(address _lp,address token0, address token1, uint256 amount0, uint256 amount1) external;

    function addrewardtoken(
        address _lp,
        address token,
        uint256 amount
    ) external;

}
