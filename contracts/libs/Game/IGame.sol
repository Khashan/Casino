pragma solidity ^0.8.4;

import "../ICasino.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IGame {
    function _init(
        ICasino _casino,
        address _owner,
        address _creator,
        uint256 _cost,
        uint256 _initialTokens,
        bool _canBeDestroyed
    ) internal;

    function cost() external view returns (uint256);

    function play(address user, uint256 _usedToken) external returns (bool);

    function setCost(uint256 cost) external;
}
