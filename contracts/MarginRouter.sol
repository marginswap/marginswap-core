
contract MarginRouter {
    
    function swapExactTokensForTokens(uint amountIn,
                                      uint amountOutMin,
                                      address[] calldata path,
                                      uint deadline)
        external returns (uint[] memory amounts) {
        return new uint[](1);
    }

    function swapTokensForExactTokens(uint amountOut,
                                      uint amountInMax,
                                      address[] calldata path,
                                      uint deadline)
        external returns (uint[] memory amounts) {
        return new uint[](1);
    }

    function getAmountsOut(uint amount, address[] memory path) external view returns (uint[] memory) {
        return new uint[](1);
    }
}
