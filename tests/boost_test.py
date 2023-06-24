
import ape
import pytest

def test_deposit(owner, weth, yweth, boost):
    weth.deposit({"from": owner, "value": "1 ether"})
    weth.approve(yweth, 2**256-1, {"from": owner})
    yweth.deposit("1 ether", {"from": owner})
    boost.deposit(yweth, {"from": owner})
    assert yweth.balanceOf(boost) == "1 ether"