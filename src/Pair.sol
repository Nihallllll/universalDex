// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pair is ERC20 {
    address public factory;
    address public token0;
    address public token1;
    uint public reserve0;
    uint public reserve1;

    event LiquidityAdded(address provider, uint amount0, uint amount1);
    event LiquidityRemoved(address provider, uint amount0, uint amount1);
    event Swap(address swapper, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out);

    constructor() ERC20("LP Token", "LPT") {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "Not factory");
        require(token0 == address(0) && token1 == address(0), "Already initialized");
        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(uint amount0Desired, uint amount1Desired) public payable returns (uint lpAmount) {
        (uint amount0, uint amount1) = token0 < token1 ? (amount0Desired, amount1Desired) : (amount1Desired, amount0Desired);
        
        if (totalSupply() == 0) {
            require(amount0 > 0 && amount1 > 0, "Invalid amounts");
            _transferTokens(token0, msg.sender, address(this), amount0);
            _transferTokens(token1, msg.sender, address(this), amount1);
            reserve0 = amount0;
            reserve1 = amount1;
            lpAmount = _sqrt(amount0 * amount1);
            _mint(msg.sender, lpAmount);
        } else {
            uint amount1Required = (amount0 * reserve1) / reserve0;
            require(amount1 == amount1Required, "Incorrect ratio");
            _transferTokens(token0, msg.sender, address(this), amount0);
            _transferTokens(token1, msg.sender, address(this), amount1);
            lpAmount = (amount0 * totalSupply()) / reserve0;
            _mint(msg.sender, lpAmount);
            reserve0 += amount0;
            reserve1 += amount1;
        }
        
        emit LiquidityAdded(msg.sender, amount0, amount1);
    }

    function removeLiquidity(uint lpAmount) public returns (uint amount0, uint amount1) {
        require(lpAmount > 0 && lpAmount <= balanceOf(msg.sender), "Invalid amount");
        uint totalLP = totalSupply();
        amount0 = (lpAmount * reserve0) / totalLP;
        amount1 = (lpAmount * reserve1) / totalLP;
        
        _burn(msg.sender, lpAmount);
        _transferTokens(token0, address(this), msg.sender, amount0);
        _transferTokens(token1, address(this), msg.sender, amount1);
        
        reserve0 -= amount0;
        reserve1 -= amount1;
        
        emit LiquidityRemoved(msg.sender, amount0, amount1);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid input");
        uint numerator = amountIn * reserveOut;
        uint denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    function swap(uint amount0Out, uint amount1Out) public payable {
        require(amount0Out == 0 || amount1Out == 0, "Invalid output");
        require(amount0Out > 0 || amount1Out > 0, "No output");
        
        uint amount0In;
        uint amount1In;
        
        if (amount0Out > 0) {
            amount1In = getAmountOut(amount0Out, reserve1, reserve0);
            _transferTokens(token1, msg.sender, address(this), amount1In);
            _transferTokens(token0, address(this), msg.sender, amount0Out);
        } else {
            amount0In = getAmountOut(amount1Out, reserve0, reserve1);
            _transferTokens(token0, msg.sender, address(this), amount0In);
            _transferTokens(token1, address(this), msg.sender, amount1Out);
        }
        
        reserve0 = reserve0 + amount0In - amount0Out;
        reserve1 = reserve1 + amount1In - amount1Out;
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out);
    }

    function _transferTokens(address token, address from, address to, uint amount) internal {
        if (token == address(0)) {
            if (from == address(this)) {
                payable(to).transfer(amount);
            } else {
                require(msg.value == amount, "Incorrect ETH amount");
            }
        } else {
            if (from == address(this)) {
                IERC20(token).transfer(to, amount);
            } else {
                IERC20(token).transferFrom(from, to, amount);
            }
        }
    }

    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    receive() external payable {}
}