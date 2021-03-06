pragma solidity ^0.8.4;

import "../ICasino.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IGame {
    function play(uint256 _usedToken) external;

    function setCost(uint256 _cost) external;

    function isDone() external view returns (bool);
}
