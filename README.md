# ar_forecast
Utilidades para acceder a datos del SMN (Argentina)

En el código fuente se observa que el token JWT se guarda en el almacenamiento del navegador para el sitio:
```html
<script type="text/javascript">
localStorage.setItem('token','theTOKENvalue');
</script>
```

El valor puede extraerse por consola (GNU/Linux POSIX compatible):
```console
$ curl -s https://www.smn.gob.ar/ | grep -oP "(?<='token',[[:space:]]').*(?=')"
```
_Puede asignarse a una variable simplemente con:_
```console
$ TOKEN=$(curl -s https://www.smn.gob.ar/ | grep -oP "(?<='token',[[:space:]]').*(?=')")
```

Con el token el navegador ejecuta en el sitio una petición para obtener datos generales
```
GET /v1/weather/location/zoom/2 HTTP/1.1
Accept: application/json
Authorization: JWT theTOKENvalue
```
La petición puede efectuarse por consola también (GNU/Linux POSIX compatible) por ej.:
```console
$ curl -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" https://ws1.smn.gob.ar/v1/weather/location/zoom/2
```
 
