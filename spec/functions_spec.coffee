# 
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs)

describe 'sum', ->
    it 'sums an array', ->
        result = sum [1,2,3]
        expect(result).toEqual(6)

describe 'ordinal', ->
    it 'returns 1st', ->
        expect(ordinal 1).toEqual '1st'
    it 'returns 2nd', ->
        expect(ordinal 2).toEqual '2nd'
    it 'returns 3rd', ->
        expect(ordinal 3).toEqual '3rd'
    it 'returns 4th', ->
        expect(ordinal 4).toEqual '4th'
    it 'returns 11th', ->
        expect(ordinal 11).toEqual '11th'
    it 'returns 20th', ->
        expect(ordinal 20).toEqual '20th'
    it 'returns 21st', ->
        expect(ordinal 21).toEqual '21st'
