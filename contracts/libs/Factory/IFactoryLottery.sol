pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../ICasino.sol";

interface IFactoryLottery {
    function createLottery(
        IERC20 _lpToken,
        uint256 _gameCost,
        uint256 _initPool
    ) external;

    function setCreationCost(uint256 cost) external;

    function getLottery(uint256 index) external view returns (Lottery);

    function getLotteryIndex(address lotteryAddress)
        external
        view
        returns (uint256);
}
