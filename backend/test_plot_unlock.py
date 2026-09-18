"""Pack/unpack plot unlock keys (mirrors PlayerCore PackPlotUnlock)."""


def pack_plot_unlock(type_index: int, item_index: int) -> int:
    return type_index * 1000 + item_index


def unpack_plot_type(packed: int) -> int:
    return packed // 1000


def unpack_plot_item(packed: int) -> int:
    return packed - unpack_plot_type(packed) * 1000


if __name__ == "__main__":
    for type_index, item_index in ((0, 0), (1, 5), (9, 42), (9, 999)):
        packed = pack_plot_unlock(type_index, item_index)
        assert unpack_plot_type(packed) == type_index, packed
        assert unpack_plot_item(packed) == item_index, packed
        assert packed not in (type_index, item_index) or item_index == 0
    assert pack_plot_unlock(2, 3) != pack_plot_unlock(3, 2)
    print("ok")
