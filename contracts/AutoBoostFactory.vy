# @version 0.3.7

BLUEPRINT: public(immutable(address))

@external
def __init__(blueprint: address):
    BLUEPRINT = blueprint


@external
def create_auto_boost(boost: address,
    owner: address,
    bot: address,
    path: Bytes[10000]) -> address:

    auto_boost: address = create_from_blueprint(
        BLUEPRINT,
        boost,
        owner,
        bot,
        path
    )

    return auto_boost
