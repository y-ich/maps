# 
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs)

describe "sum", ->
    it "sums an array", ->
        result = sum [1,2,3]
        expect(result).toEqual(6)

        