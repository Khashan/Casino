pragma solidity ^0.8.4;

import "../../libs/Game/Game.sol";

contract SlotMatchine is Game {
    uint16 public cols;
    uint16 public rows;

    struct WinData {
        uint16[] combo;
        uint256 rewardPercent;
    }

    WinData[] public winPossibilities;

    function init(
        ICasino _casino,
        address _owner,
        address _manager,
        uint256 _cost,
        uint256 _initialTokens,
        uint16 _cols,
        uint16 _rows
    ) external {
        super._init(_casino, _owner, _manager, _cost, _initialTokens, true);
        gameCost = _cost;
        cols = _cols;
        rows = _rows;
    }

    function play(uint256 _usedToken) external override returns (bool) {
        _playVerification(_usedToken);

        require(winPossibilities.length > 3, "Not enough win possibilities");
        casino.takeToken(msg.sender, gameCost);

        uint256[] memory results = casino.getRandomNumbers(cols, rows, 0);
        uint256 possLength = winPossibilities.length;
        uint256 winPool = casino.getGameTokens(this);

        // for (uint256 i = 0; i < possLength; i++) {
        //     WinData memory win = winPossibilities[i];

        //     if (win.combo == results) {
        //         casino.transferToken(
        //             user,
        //             winPool.mul(win.rewardPercent).div(10000)
        //         );
        //         return true;
        //     }
        // }

        return false;
    }

    function addWinPosibility(uint16[] memory _combo, uint256 _rewardPercent)
        external
        isCreator
    {
        require((_combo.length - 1) == cols, "Not enough cols");
        winPossibilities.push(WinData(_combo, _rewardPercent));
    }

    function removeWinPosibility(uint256 _index) external isCreator {
        require(winPossibilities.length > _index, "Index too high");
        uint256 length = winPossibilities.length - 1;

        winPossibilities[_index] = winPossibilities[length];
        winPossibilities.pop();
    }
}
