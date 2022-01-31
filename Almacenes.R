################################
# Analisis Almacenes N.Pizarro #
################################
setwd("~/Documents/Proyectos")
library(readxl)
library(tidyverse)
library(lubridate)
library(plotly)
options(scipen = 999)

# Data --------------------------------------------------------------------
ventas <- read_excel("~/Downloads/data ventas 10-06-21.xlsx")
names(ventas) <- gsub(" ", "_", tolower(names(ventas))) # arreglo de columnas
ventas <- ventas %>% select(nombre_almacen:codigo_de_barra) %>% # filtrando columnas
  mutate(fecha = dmy(fecha),
         semana = floor_date(fecha, "weeks", week_start = 1),
         precio_venta = total/cantidad,
         margen = total/cantidad - precio_de_compra)

# Descripción Almacenes ----------------------------------------------------
glimpse(ventas)

# ¿Cuántos almacenes hay?
ventas %>% 
  select(nombre_almacen) %>% 
  distinct() %>% 
  count() # 464 almacenes

# ¿Desde cuándo?
ventas %>% 
  group_by(semana) %>% 
  summarise(n = n_distinct(nombre_almacen)) %>% 
  plot_ly(x = ~semana, y = ~n, type = 'scatter', mode = 'lines+markers') %>% 
  layout(xaxis = list(title = ""), yaxis = list(title = "Almacenes únicos"))

# ¿Frecuencia de operación periodo?
# Top 5 almacenes
# 1. Don tito
# 2. Donde el vecino
# 3. Pulperia Alemana
# 4. Emporio la pitu
# 5. Yolita
ventas_op <- ventas %>% 
  count(nombre_almacen, sort = TRUE) %>% 
  mutate(porc = n/sum(n)*100) %>% 
  print(n = 50)

# Con 80 almacenes explica el 96% de la data desde enero
map_df(c(5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80), function(x) {
  ventas_op %>% 
    head(x) %>% 
    summarise(corte = x, 
              porc_sum = sum(porc))
})

# Con 80 almacenes explica el 97% de la data desde Marzo
map_df(c(5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80), function(x) {
  ventas %>% 
    filter(semana >= as.Date("2021-03-01")) %>% 
    count(nombre_almacen, sort = TRUE) %>% 
    mutate(porc = n/sum(n)*100) %>% 
    head(x) %>% 
    summarise(corte = x, 
              porc_sum = sum(porc))
})


# ¿Transacciones y volumen por semana? (desde marzo)
ventas_prom <- ventas %>% 
  filter(semana >= as.Date("2021-03-01")) %>% 
  group_by(semana, nombre_almacen) %>% 
  summarise(n = n(),
            tipos_productos = n_distinct(nombre_producto),
            volumen_productos = sum(cantidad),
            monto = sum(total)) %>% 
  group_by(nombre_almacen) %>% 
  summarise(n_semanas = n(), 
            prom_trx = mean(n),
            prom_tipos_prod = mean(tipos_productos),
            prom_vol_prod = mean(volumen_productos),
            prom_monto = mean(monto)) %>% 
  arrange(desc(prom_monto)) %>% 
  print(n = 20) 

ventas_prom %>% 
  arrange(desc(n_semanas), desc(prom_trx)) %>% View

ventas %>% filter(nombre_almacen == "BOLLERIA EDEL") %>% View

# Descripción productos ----------------------------------------------------
#¿Producto más vendido en promedio por semana? (desde marzo)
prod_ventas <- ventas %>% 
  filter(semana >= as.Date("2021-03-01")) %>%
  group_by(semana, nombre_producto) %>% 
  summarise(n_cantidad = sum(cantidad),
            n_almacenes = n_distinct(nombre_almacen),
            precio_prom = mean(precio_venta),
            precio_sd = sd(precio_venta),
            precio_max = max(precio_venta),
            precio_min = min(precio_venta)) %>% 
  group_by(nombre_producto) %>% 
  summarise(n_cantidad = mean(n_cantidad),
            n_almacenes = mean(n_almacenes),
            precio_prom = mean(precio_prom),
            precio_sd = mean(precio_sd),
            precio_max = mean(precio_max),
            precio_min = mean(precio_min)) %>% 
  arrange(desc(n_cantidad))

#¿Producto vendidos mes? (desde marzo)
prod_ventas_ventana4m <- ventas %>% 
  filter(semana >= as.Date("2021-03-01"), region = "METROPOLITANA") %>%
  group_by(nombre_almacen, nombre_producto) %>% 
  summarise(n_cantidad = sum(cantidad),
            precio = mean(precio_venta)) %>% 
  ungroup() %>% 
  group_by(nombre_producto) %>% 
  summarise(n = n(),
            precio_prom = mean(precio),
            precio_sd = sd(precio, na.rm = TRUE))
            
            
prod_ventas_ventana4m %>% 
  mutate(precio_se = precio_sd/sqrt(n),
         margen_error = 1.96*precio_se,
         perc_margen_error = margen_error/precio_prom*100,
         int_sup = precio_prom + margen_error,
         int_inf = precio_prom - margen_error,
         rango_int = int_sup - int_inf) %>% View

# Mirando algunos productos 
ventas %>% 
  filter(nombre_producto == "QUESO GAUDA SOPROLE") %>% 
  count(nombre_almacen) 

ventas %>% 
  filter(nombre_producto == "TUTRO ENTERO") %>% View

ventas %>% 
  filter(nombre_producto == "DORITOS 110 GR EVERCRISP") %>% 
  group_by(region) %>% 
  summarise(n_almacenes = n_distinct(nombre_almacen),
            cantidad_prom = sum(cantidad), 
            precio_prom = mean(precio_de_compra),
            precio_max = max(precio_de_compra),
            precio_min = min(precio_de_compra)) %>% 
  arrange(desc(precio_prom))

ventas %>% 
  filter(nombre_producto == "LECHE SURLAT ENTERA 1LT SURLAT") %>% 
  group_by(nombre_almacen, comuna) %>% 
  summarise(cantidad_prom = sum(cantidad), 
            precio_prom = mean(precio_de_compra),
            precio_max = max(precio_de_compra),
            precio_min = min(precio_de_compra)) %>% 
  arrange(desc(precio_prom))

ventas %>% 
  filter(nombre_producto == "LECHE SURLAT ENTERA 1LT SURLAT") %>% 
  group_by(region) %>% 
  summarise(n_almacenes = n_distinct(nombre_almacen),
            precio_prom = mean(precio_de_compra),
            precio_max = max(precio_de_compra),
            precio_min = min(precio_de_compra)) %>% 
  arrange(desc(precio_prom))

ventas %>% 
  filter(grepl("membrillo", tolower(nombre_producto))) %>% 
  count(nombre_producto)

ventas %>% 
  filter(nombre_producto == "WATTS DULCEMEMBRILLO FRUTA 250GR WATTS") %>% 
  group_by(region) %>% 
  summarise(n_almacenes = n_distinct(nombre_almacen),
            precio_prom = mean(precio_venta),
            sd_precio = sd(precio_venta),
            precio_max = max(precio_venta),
            precio_min = min(precio_venta)) %>% 
  arrange(desc(precio_prom))

(n <- (68.1*1.96/(819 - 819*1.04))^2)
(n <- (68.1*1.96/(819*1.02 - 819))^2)

# Definiendo zonas --------------------------------------------------------
ventas %>% count(region, sort = TRUE)
ventas_zn <- ventas %>% 
  mutate(zona = case_when(region %in% c("DE ARICA Y PARINACOTA", "TARAPACA", "ANTOFAGASTA") ~ "Macrozona_1",
                          region %in% c("ATACAMA", "COQUIMBO") ~ "Macrozona_2",
                          region %in% c("VALPARAISO") ~ "Macrozona_3",
                          region %in% c("METROPOLITANA DE SANTIAGO") ~ "Macrozona_4",
                          region %in% c("DEL LIBERTADOR BERNARDO O'HIGGINS", "DEL MAULE", "DE ÑUBLE", "DEL BIO BIO", "CORONEL") ~ "Macrozona_5",
                          region %in% c("DE LA ARAUCANIA", "DE LOS RIOS", "DE LOS LAGOS", "AISEN DEL GENERAL CARLOS IBAÑEZ DEL CAMPO") ~"Macrozona_6",
                          region %in% c("DE MAGALLANES Y DE LA ANTARTICA CHILENA") ~ "Macrozona_7",
                          TRUE ~ "chupalaquecuelga"))

ventas_zn %>% count(zona)


