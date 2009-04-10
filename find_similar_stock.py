#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sqlite3
import csv
import re
import math
import sys

class Price:
    def __init__(self):
        self.con = sqlite3.connect("dat/stocks.db")
        self.con.row_factory = sqlite3.Row
        
    def closing_prices(self, code):
        c = self.con.cursor()
        c.execute("select * from stock where code = %i order by date" % code)
        return [row[5] for row in c][-25:]

    def close_and_volume(self, code):
        c = self.con.cursor()
        c.execute("select * from stock where code = %i order by date" % code)
        prices = [(row[5], row[6]) for row in c]
        return (None, None) if len(prices) == 0 else prices[-1]

def isdigit(n):
    return re.search('\d{4}', n)

def codes():
    reader = csv.reader(file("dat/codes.txt"))
    h = {}
    for row in reader:
        if len(row) != 10:
            continue

        if not isdigit(row[0]):
            continue
        
        if not int(row[0]) in h:
            h[int(row[0])] = row[2]

    return h

def correlation(xs, ys):
    avgx = sum(xs) / float(len(xs))
    avgy = sum(ys) / float(len(ys))
    l = sum([(x - avgx) * (y - avgy) for x, y in zip(xs, ys)])
    m = sum([(x - avgx) ** 2 for x in xs])
    n = sum([(y - avgy) ** 2 for y in ys])
    if m == 0 or n ==0:
        return 0
    else:
        return l / (math.sqrt(m) * math.sqrt(n))

# public
def find_similar_stock(code):
    price = Price()
    xs = price.closing_prices(code)
    results = []
    cs = codes()
    for c in cs:
        if c == code:
            continue
        ys = price.closing_prices(c)
        if len(ys) == 0:
            continue
        results.append((c, correlation(xs, ys)))
    results.sort(lambda x, y: cmp(y[1] ,x[1]))

    for x, y in results[:10]:
        print x, cs[x], y

def search_boro_kabu():
    cs = codes()
    price = Price()
    results = []
    for c in cs:
        p, v = price.close_and_volume(c) 
        if p == None:
            continue
        # 価格が200円未満で、売買代金１億円以上
        if p < 200 and p * v > 100000000:
            results.append((p * v, c))
    results.sort(lambda x, y: cmp(y[0], x[0]))

    for v, c in results:
        print c, cs[c], v

    f = open("boro_kabu.txt", "w")
    for v, c in results:
        f.write(str(c) + "\n")
    f.close()

    os.popen("ruby rakuten_rss.rb")


if __name__ == '__main__':
    code = int(sys.argv[1])
    search_boro_kabu()
    #find_similar_stock(code)
