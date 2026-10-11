# -*- coding: utf-8 -*-
"""A Heptarchia népenkénti zenéi – minden népnek saját darab.

A kották három fájlban vannak:
  nepek_brit.py    – a Brit-szigetek és Normandia (az alapjáték 14 népe)
  nepek_eszak.py   – az északiak, a baltiak, a finnek, a számik, a szlávok
  nepek_del.py     – a frankok, Itália, Ibéria, az iszlám világ, Bizánc,
                     a Kaukázus és a sztyeppe népei
Egy darab = keret.Darab; az azonosítója (azon) a nép játékbeli azonosítója
(GameManager.faction_id), a kész fájl neve ennek kisbetűs alakja.
"""
import nepek_brit
import nepek_del
import nepek_eszak

DARABOK = list(nepek_brit.DARABOK) + list(nepek_eszak.DARABOK) + list(nepek_del.DARABOK)
