import pytest
from ape import Contract, project

@pytest.fixture(scope="session")
def owner(accounts):
    return accounts[0]

@pytest.fixture(scope="session")
def bot(accounts):
    return accounts[1]

@pytest.fixture(scope="session")
def rando(accounts):
    return accounts[2]

@pytest.fixture(scope="session")
def weth():
    return Contract("0x5B977577Eb8a480f63e11FC615D6753adB8652Ae")

@pytest.fixture(scope="session")
def yweth():
    return Contract("0x4200000000000000000000000000000000000006")

@pytest.fixture(scope="session")
def yweth_boost():
    return Contract("0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0")

@pytest.fixture
def boost(project, owner, yweth_boost, bot):
    owner.deploy(project.AutoBoost, yweth_boost.address, owner.address, bot.address)
