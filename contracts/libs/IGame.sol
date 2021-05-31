pragma solidity ^0.8.4;

interface IGame {
    function cost() external view returns (uint256);

    function play(address user, uint256 _usedToken) external returns (bool);
}
